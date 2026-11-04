/*
 * lastday_nav.c — "LastDayNav" GDExtension in plain C for Godot 4.7.
 *
 * Native port of scripts/NavPathfinding.gd (grid A* for wildlife). Exposes a
 * RefCounted class "LastDayNav" with the same duck-typed surface used by
 * Main.gd: build(blockers, rivers), find_path(start, goal) -> Array[Vector3],
 * is_cell_blocked(cell) -> bool, update_door_cache(blockers, f1, f2),
 * is_built() -> bool. The two Callable args of update_door_cache are accepted
 * and ignored: the doorway geometry is replicated natively so no callbacks
 * into GDScript are needed.
 *
 * Data layout per instance: dense uint8/int32 arrays over a 484x700 grid
 * (world x -484..484, z -500..900 at 2 m cells) instead of Dictionary-of-
 * Vector2i, plus a binary-heap A*. No Godot objects are touched after build.
 */

#include "gdextension_interface.h"

#include <math.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

#ifndef GDE_EXPORT
#if defined(_WIN32)
#define GDE_EXPORT __declspec(dllexport)
#else
#define GDE_EXPORT __attribute__((visibility("default")))
#endif
#endif

/* ---------------- Variant/opaque storage ----------------
 * GDExtension treats these as opaque; give them generous aligned buffers.
 * A Variant in official 4.x 64-bit builds is 24 bytes; 64 bytes is future-proof.
 */
typedef struct {
	_Alignas(16) uint8_t b[64];
} VarSlot;

typedef struct {
	_Alignas(16) uint8_t b[32];
} TypeSlot;

/* real_t in standard Godot builds is float; Vector2i components are int32. */
typedef struct { float x, y, z; } V3;
typedef struct { float x, y; } V2;
typedef struct { int32_t x, y; } V2i;
typedef struct { float px, py, sx, sy; } R2;

/* ---------------- Grid constants (must match NavPathfinding.gd) ---------------- */
#define GRID_W 484
#define GRID_H 700
#define GRID_N (GRID_W * GRID_H)
#define GRID_X_OFF (GRID_W / 2)
#define GRID_Z_OFF 250
#define CELL_SIZE 2.0f

#define SQRT2F 1.41421356237f

/* ---------------- NavGrid ---------------- */
typedef struct {
	uint8_t *blocked;    /* GRID_N: static solids (blockers + water) */
	uint8_t *door_open;  /* GRID_N: cells freed by an open door */
	int32_t *regions;    /* GRID_N: flood-filled region id, -1 blocked, 0 unvisited */
	int32_t *door_group; /* GRID_N: union group for door-open cells, -1 = none */
	int32_t *door_cells; /* compact list of cells belonging to door regions */
	int32_t door_cell_count;
	int32_t n_regions;   /* region ids are 1..n_regions */
	int32_t *edge_cells; /* CSR: boundary cells of all regions */
	int32_t *edge_off;   /* CSR offsets, size n_regions+2 */
	int32_t *region_groups; /* union-find roots, size >= n_groups */
	int32_t n_groups;
	int built;
	/* scratch for A* / BFS (allocated once, reused) */
	int32_t *queue;
	float *g_cost;
	float *f_cost;
	int32_t *came_from;
	uint8_t *closed;
	uint32_t *seen_gen;
	uint32_t search_gen;
	int32_t *heap;
	int32_t *heap_pos;
} NavGrid;

/* ---------------- Interface function pointers ---------------- */
static GDExtensionClassLibraryPtr g_lib;

static GDExtensionInterfaceMemAlloc fn_mem_alloc;
static GDExtensionInterfaceMemRealloc fn_mem_realloc;
static GDExtensionInterfaceMemFree fn_mem_free;
static GDExtensionInterfacePrintError fn_print_error;
static GDExtensionInterfaceVariantNewNil fn_variant_new_nil;
static GDExtensionInterfaceVariantDestroy fn_variant_destroy;
static GDExtensionInterfaceVariantCall fn_variant_call;
static GDExtensionInterfaceVariantGet fn_variant_get;
static GDExtensionInterfaceVariantGetType fn_variant_get_type;
static GDExtensionInterfaceVariantConstruct fn_variant_construct;
static GDExtensionInterfaceGetVariantFromTypeConstructor fn_get_v_from_t;
static GDExtensionInterfaceGetVariantToTypeConstructor fn_get_v_to_t;
static GDExtensionInterfaceVariantGetPtrDestructor fn_get_v_dtor;
static GDExtensionInterfaceStringNewWithLatin1Chars fn_string_new;
static GDExtensionInterfaceStringNameNewWithLatin1Chars fn_sname_new;
static GDExtensionInterfaceArrayOperatorIndexConst fn_array_index;
static GDExtensionInterfaceClassdbConstructObject3 fn_construct_object;
static GDExtensionInterfaceClassdbRegisterExtensionClass6 fn_register_class;
static GDExtensionInterfaceClassdbRegisterExtensionClassMethod fn_register_method;
static GDExtensionInterfaceObjectSetInstance fn_object_set_instance;

/* Cached converters. */
static GDExtensionVariantFromTypeConstructorFunc var_from_bool;
static GDExtensionVariantFromTypeConstructorFunc var_from_string;
static GDExtensionVariantFromTypeConstructorFunc var_from_vec3;
static GDExtensionVariantFromTypeConstructorFunc var_from_v2i;
static GDExtensionTypeFromVariantConstructorFunc var_to_bool;
static GDExtensionTypeFromVariantConstructorFunc var_to_int;
static GDExtensionTypeFromVariantConstructorFunc var_to_float;
static GDExtensionTypeFromVariantConstructorFunc var_to_v2;
static GDExtensionTypeFromVariantConstructorFunc var_to_v2i;
static GDExtensionTypeFromVariantConstructorFunc var_to_v3;
static GDExtensionTypeFromVariantConstructorFunc var_to_r2;
static GDExtensionTypeFromVariantConstructorFunc var_to_arr;
static GDExtensionPtrDestructor dtor_string;
static GDExtensionPtrDestructor dtor_sname;
static GDExtensionPtrDestructor dtor_arr;

/* Persistent StringNames (live for the extension's lifetime). */
static TypeSlot sn_class, sn_parent, sn_empty;
static TypeSlot sn_m_build, sn_m_find_path, sn_m_is_blocked, sn_m_update_door_cache, sn_m_is_built;
static TypeSlot sn_m_world_to_grid, sn_m_grid_to_world, sn_m_is_path_clear;
static TypeSlot sn_size, sn_push_back, sn_call;
static TypeSlot s_hint; /* empty String for PropertyInfo.hint_string */

static void sname_make(TypeSlot *slot, const char *s) {
	fn_sname_new(slot, s, 0);
}
static void sname_free(TypeSlot *slot) {
	dtor_sname(slot);
}

/* ---------------- Forward decls ---------------- */
static void update_region_groups(NavGrid *g);
static V2i nearest_free_cell(NavGrid *g, V2i cell);
static void push_v3(GDExtensionVariantPtr arr_var, V3 v);

/* ---------------- Variant helpers ---------------- */

/* Construct a Variant holding a String (for Dictionary key lookups). */
static void key_variant(const char *key, VarSlot *out) {
	TypeSlot str;
	fn_string_new(&str, key);
	var_from_string(out, &str);
	dtor_string(&str);
}

/* variant_get on a Dictionary: returns 1 and fills out when the key exists. */
static int dict_get(GDExtensionConstVariantPtr dict_var, const char *key, VarSlot *out) {
	VarSlot k;
	GDExtensionBool valid = 0;
	fn_variant_new_nil(out); /* variant_get may leave r_ret untouched on miss */
	key_variant(key, &k);
	fn_variant_get(dict_var, &k, out, &valid);
	fn_variant_destroy(&k);
	if (!valid || fn_variant_get_type(out) == GDEXTENSION_VARIANT_TYPE_NIL)
		return 0;
	return 1;
}

static float dict_float(GDExtensionConstVariantPtr dict_var, const char *key, float fallback) {
	VarSlot v;
	float out = fallback;
	if (dict_get(dict_var, key, &v)) {
		GDExtensionVariantType t = fn_variant_get_type(&v);
		if (t == GDEXTENSION_VARIANT_TYPE_FLOAT) {
			double d = 0.0;
			var_to_float(&d, &v);
			out = (float)d;
		} else if (t == GDEXTENSION_VARIANT_TYPE_INT) {
			int64_t n = 0;
			var_to_int(&n, &v);
			out = (float)n;
		}
		fn_variant_destroy(&v);
	}
	return out;
}

static int dict_bool(GDExtensionConstVariantPtr dict_var, const char *key) {
	VarSlot v;
	int out = 0;
	if (dict_get(dict_var, key, &v)) {
		if (fn_variant_get_type(&v) == GDEXTENSION_VARIANT_TYPE_BOOL) {
			GDExtensionBool b = 0;
			var_to_bool(&b, &v);
			out = b ? 1 : 0;
		}
		fn_variant_destroy(&v);
	}
	return out;
}

static int dict_vec3(GDExtensionConstVariantPtr dict_var, const char *key, V3 *out) {
	VarSlot v;
	if (!dict_get(dict_var, key, &v))
		return 0;
	if (fn_variant_get_type(&v) != GDEXTENSION_VARIANT_TYPE_VECTOR3) {
		fn_variant_destroy(&v);
		return 0;
	}
	var_to_v3(out, &v);
	fn_variant_destroy(&v);
	return 1;
}

static int dict_vec2(GDExtensionConstVariantPtr dict_var, const char *key, V2 *out) {
	VarSlot v;
	if (!dict_get(dict_var, key, &v))
		return 0;
	if (fn_variant_get_type(&v) != GDEXTENSION_VARIANT_TYPE_VECTOR2) {
		fn_variant_destroy(&v);
		return 0;
	}
	var_to_v2(out, &v);
	fn_variant_destroy(&v);
	return 1;
}

static int dict_rect2(GDExtensionConstVariantPtr dict_var, const char *key, R2 *out) {
	VarSlot v;
	if (!dict_get(dict_var, key, &v))
		return 0;
	if (fn_variant_get_type(&v) != GDEXTENSION_VARIANT_TYPE_RECT2) {
		fn_variant_destroy(&v);
		return 0;
	}
	var_to_r2(out, &v);
	fn_variant_destroy(&v);
	return 1;
}

/* Size of an Array Variant via its "size" builtin method. */
static int64_t array_len(GDExtensionVariantPtr arr_var) {
	VarSlot ret;
	GDExtensionCallError err;
	fn_variant_new_nil(&ret);
	fn_variant_call(arr_var, &sn_size, NULL, 0, &ret, &err);
	int64_t n = 0;
	if (err.error == GDEXTENSION_CALL_OK && fn_variant_get_type(&ret) == GDEXTENSION_VARIANT_TYPE_INT) {
		var_to_int(&n, &ret);
	}
	fn_variant_destroy(&ret);
	return n;
}

/* Extract the opaque Array handle from an Array Variant. */
static void array_handle(GDExtensionVariantPtr arr_var, TypeSlot *out) {
	var_to_arr(out, arr_var);
}

/* ---------------- Grid math ---------------- */

static inline int in_bounds_cell(int x, int y) {
	return x >= 1 && x < GRID_W - 1 && y >= 1 && y < GRID_H - 1;
}

static inline int cell_idx(int x, int y) {
	return y * GRID_W + x;
}

static inline V2i world_to_grid(V3 p) {
	if (!isfinite(p.x) || !isfinite(p.z))
		return (V2i){ -1000, -1000 };
	V2i c = { (int32_t)roundf(p.x / CELL_SIZE) + GRID_X_OFF,
	          (int32_t)roundf(p.z / CELL_SIZE) + GRID_Z_OFF };
	return c;
}

static inline V3 grid_to_world(V2i c) {
	V3 w = { (float)(c.x - GRID_X_OFF) * CELL_SIZE, 0.0f,
	         (float)(c.y - GRID_Z_OFF) * CELL_SIZE };
	return w;
}

static inline int cell_blocked(const NavGrid *g, V2i c) {
	if (!in_bounds_cell(c.x, c.y))
		return 1;
	int i = cell_idx(c.x, c.y);
	return g->blocked[i] && !g->door_open[i];
}

static inline int cell_solid_raw(const NavGrid *g, int x, int y) {
	if (!in_bounds_cell(x, y))
		return 1;
	int i = cell_idx(x, y);
	return g->blocked[i] && !g->door_open[i];
}

/* Passable for A* / regions: blocked cells freed by open doors count walkable. */
static inline int cell_passable(const NavGrid *g, int x, int y) {
	return !cell_solid_raw(g, x, y);
}

/* ---------------- Region flood fill + union find ---------------- */

static int region_root(NavGrid *g, int r) {
	while (g->region_groups[r] != r)
		r = g->region_groups[r];
	return r;
}

static void nav_free_regions(NavGrid *g) {
	if (g->regions) { fn_mem_free(g->regions); g->regions = NULL; }
	if (g->edge_cells) { fn_mem_free(g->edge_cells); g->edge_cells = NULL; }
	if (g->edge_off) { fn_mem_free(g->edge_off); g->edge_off = NULL; }
	if (g->region_groups) { fn_mem_free(g->region_groups); g->region_groups = NULL; }
	if (g->door_group) { fn_mem_free(g->door_group); g->door_group = NULL; }
	if (g->door_cells) { fn_mem_free(g->door_cells); g->door_cells = NULL; }
	g->n_regions = 0;
	g->n_groups = 0;
	g->door_cell_count = 0;
}

static void build_regions(NavGrid *g) {
	nav_free_regions(g);
	g->regions = (int32_t *)fn_mem_alloc(sizeof(int32_t) * GRID_N);
	for (int y = 0; y < GRID_H; y++)
		for (int x = 0; x < GRID_W; x++) {
			int i = cell_idx(x, y);
			g->regions[i] = cell_solid_raw(g, x, y) ? -1 : 0;
		}

	/* Pass 1: flood fill regions, counting boundary cells per region. */
	size_t max_regions = (size_t)(GRID_N / 2 + 2);
	int32_t *counts = (int32_t *)fn_mem_alloc(sizeof(int32_t) * max_regions);
	memset(counts, 0, sizeof(int32_t) * max_regions);
	int n_regions = 0;
	for (int origin = 0; origin < GRID_N; origin++) {
		if (g->regions[origin] != 0)
			continue;
		int region = ++n_regions;
		int head = 0, tail = 1;
		g->queue[0] = origin;
		g->regions[origin] = region;
		while (head < tail) {
			int idx = g->queue[head++];
			int boundary = 0;
			int nb[4] = { idx - 1, idx + 1, idx - GRID_W, idx + GRID_W };
			for (int k = 0; k < 4; k++) {
				int n = nb[k];
				if (g->regions[n] < 0)
					boundary = 1;
				else if (g->regions[n] == 0) {
					g->regions[n] = region;
					g->queue[tail++] = n;
				}
			}
			if (boundary)
				counts[region]++;
		}
	}

	/* Pass 2: write edge cells into CSR arrays. */
	g->n_regions = n_regions;
	g->edge_off = (int32_t *)fn_mem_alloc(sizeof(int32_t) * (n_regions + 2));
	g->edge_off[0] = 0;
	g->edge_off[1] = 0;
	for (int r = 1; r <= n_regions; r++)
		g->edge_off[r + 1] = g->edge_off[r] + counts[r];
	int total_edges = g->edge_off[n_regions + 1];
	g->edge_cells = (int32_t *)fn_mem_alloc(sizeof(int32_t) * (total_edges > 0 ? total_edges : 1));
	int32_t *cursor = (int32_t *)fn_mem_alloc(sizeof(int32_t) * (n_regions + 2));
	memcpy(cursor, g->edge_off, sizeof(int32_t) * (n_regions + 2));
	for (int origin = 0; origin < GRID_N; origin++) {
		int r = g->regions[origin];
		if (r <= 0)
			continue;
		int nb[4] = { origin - 1, origin + 1, origin - GRID_W, origin + GRID_W };
		int boundary = 0;
		for (int k = 0; k < 4; k++)
			if (g->regions[nb[k]] < 0) { boundary = 1; break; }
		if (boundary)
			g->edge_cells[cursor[r]++] = origin;
	}
	fn_mem_free(cursor);
	fn_mem_free(counts);

	update_region_groups(g);
}

static int cell_region(NavGrid *g, int idx) {
	return g->door_group[idx] >= 0 ? g->door_group[idx] : g->regions[idx];
}

/* Rebuild union-find groups (regions joined through open doors). */
static void update_region_groups(NavGrid *g) {
	if (g->door_group) fn_mem_free(g->door_group);
	if (g->door_cells) fn_mem_free(g->door_cells);
	if (g->region_groups) fn_mem_free(g->region_groups);

	g->door_group = (int32_t *)fn_mem_alloc(sizeof(int32_t) * GRID_N);
	memset(g->door_group, 0xFF, sizeof(int32_t) * GRID_N); /* -1 */
	g->door_cells = (int32_t *)fn_mem_alloc(sizeof(int32_t) * GRID_N);
	g->door_cell_count = 0;

	int cap = g->n_regions + GRID_N / 2 + 8;
	g->region_groups = (int32_t *)fn_mem_alloc(sizeof(int32_t) * cap);
	for (int i = 0; i < cap; i++)
		g->region_groups[i] = i;
	int n_groups = g->n_regions + 1;

	int32_t *adjacent = (int32_t *)fn_mem_alloc(sizeof(int32_t) * (g->n_regions + 2));
	for (int origin = 0; origin < GRID_N; origin++) {
		int ox = origin % GRID_W, oy = origin / GRID_W;
		if (!g->door_open[origin] || cell_solid_raw(g, ox, oy) || g->door_group[origin] >= 0)
			continue;
		/* BFS the connected door-open blob; collect adjacent walkable regions. */
		int head = 0, tail = 1;
		g->queue[0] = origin;
		g->door_group[origin] = 0;
		int flood_start = g->door_cell_count;
		g->door_cells[g->door_cell_count++] = origin;
		int n_adj = 0;
		while (head < tail) {
			int idx = g->queue[head++];
			int cx = idx % GRID_W, cy = idx / GRID_W;
			static const int dx[4] = { -1, 1, 0, 0 };
			static const int dy[4] = { 0, 0, -1, 1 };
			for (int k = 0; k < 4; k++) {
				int nx = cx + dx[k], ny = cy + dy[k];
				if (nx < 1 || ny < 1 || nx >= GRID_W - 1 || ny >= GRID_H - 1)
					continue;
				int n = cell_idx(nx, ny);
				if (g->door_open[n]) {
					if (g->door_group[n] < 0) {
						g->door_group[n] = 0;
						g->queue[tail++] = n;
						g->door_cells[g->door_cell_count++] = n;
					}
				} else {
					int r = g->regions[n];
					if (r > 0) {
						int seen = 0;
						for (int a = 0; a < n_adj; a++)
							if (adjacent[a] == r) { seen = 1; break; }
						if (!seen)
							adjacent[n_adj++] = r;
					}
				}
			}
		}
		if (n_groups >= cap)
			break; /* absurd door-cell count; keep grid consistent */
		int group = n_groups++;
		for (int a = 0; a < n_adj; a++)
			g->region_groups[region_root(g, adjacent[a])] = group;
		for (int i = flood_start; i < g->door_cell_count; i++)
			g->door_group[g->door_cells[i]] = group;
	}
	fn_mem_free(adjacent);
	g->n_groups = n_groups;
	for (int r = 0; r < n_groups; r++)
		g->region_groups[r] = region_root(g, r);
}

/* nearest reachable cell when start/goal are in different groups */
static V2i reachable_goal(NavGrid *g, V2i start, V2i goal) {
	int group = region_root(g, cell_region(g, cell_idx(start.x, start.y)));
	if (group == region_root(g, cell_region(g, cell_idx(goal.x, goal.y))))
		return goal;
	V2i nearest = start;
	double dist = (double)(start.x - goal.x) * (start.x - goal.x) +
	              (double)(start.y - goal.y) * (start.y - goal.y);
	for (int r = 1; r <= g->n_regions; r++) {
		if (region_root(g, r) != group)
			continue;
		for (int i = g->edge_off[r]; i < g->edge_off[r + 1]; i++) {
			int c = g->edge_cells[i];
			int cx = c % GRID_W, cy = c / GRID_W;
			double d = (double)(cx - goal.x) * (cx - goal.x) +
			           (double)(cy - goal.y) * (cy - goal.y);
			if (d < dist) {
				dist = d;
				nearest.x = cx;
				nearest.y = cy;
			}
		}
	}
	for (int i = 0; i < g->door_cell_count; i++) {
		int c = g->door_cells[i];
		if (region_root(g, cell_region(g, c)) != group)
			continue;
		int cx = c % GRID_W, cy = c / GRID_W;
		double d = (double)(cx - goal.x) * (cx - goal.x) +
		           (double)(cy - goal.y) * (cy - goal.y);
		if (d < dist) {
			dist = d;
			nearest.x = cx;
			nearest.y = cy;
		}
	}
	return nearest;
}

/* ---------------- World-space clear check ---------------- */

static int path_clear(NavGrid *g, V3 a, V3 b) {
	float dx = b.x - a.x, dz = b.z - a.z;
	float dist = sqrtf(dx * dx + dz * dz);
	if (dist < 0.01f)
		return 1;
	float ux = dx / dist, uz = dz / dist;
	int steps = (int)ceilf(dist / (CELL_SIZE * 0.5f));
	V2i prev = world_to_grid(a);
	for (int i = 0; i <= steps; i++) {
		float t = dist * (float)i / (float)steps;
		V2i cell = world_to_grid((V3){ a.x + ux * t, 0.0f, a.z + uz * t });
		if (cell_blocked(g, cell))
			return 0;
		if (cell.x != prev.x && cell.y != prev.y) {
			V2i c1 = { cell.x, prev.y }, c2 = { prev.x, cell.y };
			if (cell_blocked(g, c1) || cell_blocked(g, c2))
				return 0;
		}
		prev = cell;
	}
	return 1;
}

/* ---------------- A* (binary heap, octile heuristic, diagonal w/ corner check) ---------------- */

static inline float h_octile(int dx, int dy) {
	int adx = dx < 0 ? -dx : dx;
	int ady = dy < 0 ? -dy : dy;
	int mn = adx < ady ? adx : ady;
	int mx = adx > ady ? adx : ady;
	return (float)mx + (SQRT2F - 1.0f) * (float)mn;
}

static void heap_push_or_decrease(NavGrid *g, int node) {
	int n = g->heap_pos[node];
	if (n == 0) {
		n = ++g->heap[0];
		g->heap[n] = node;
		g->heap_pos[node] = n;
	}
	while (n > 1) {
		int p = n / 2;
		int pn = g->heap[p];
		if (g->f_cost[pn] <= g->f_cost[node])
			break;
		g->heap[n] = pn;
		g->heap_pos[pn] = n;
		n = p;
	}
	g->heap[n] = node;
	g->heap_pos[node] = n;
}

static int heap_pop(NavGrid *g) {
	int top = g->heap[1];
	g->heap_pos[top] = 0;
	int n = --g->heap[0];
	if (n > 0) {
		int last = g->heap[n + 1];
		int i = 1;
		for (;;) {
			int l = i * 2, r = l + 1, m = i;
			float mf = g->f_cost[last];
			if (l <= n && g->f_cost[g->heap[l]] < mf) {
				m = l;
				mf = g->f_cost[g->heap[l]];
			}
			if (r <= n && g->f_cost[g->heap[r]] < mf)
				m = r;
			if (m == i)
				break;
			int child = g->heap[m];
			g->heap[i] = child;
			g->heap_pos[child] = i;
			i = m;
		}
		g->heap[i] = last;
		g->heap_pos[last] = i;
	}
	return top;
}

static inline void touch_cell(NavGrid *g, int idx, uint32_t gen) {
	if (g->seen_gen[idx] != gen) {
		g->seen_gen[idx] = gen;
		g->g_cost[idx] = 1e30f;
		g->f_cost[idx] = 1e30f;
		g->came_from[idx] = -1;
		g->closed[idx] = 0;
		g->heap_pos[idx] = 0;
	}
}

static int astar(NavGrid *g, V2i start, V2i goal, int32_t *out_cells, int max_out) {
	uint32_t gen = ++g->search_gen;
	if (gen == 0) {
		memset(g->seen_gen, 0, sizeof(uint32_t) * GRID_N);
		gen = ++g->search_gen;
	}
	int sx = start.x, sy = start.y, gx = goal.x, gy = goal.y;
	int sidx = cell_idx(sx, sy), gidx = cell_idx(gx, gy);
	touch_cell(g, sidx, gen);
	touch_cell(g, gidx, gen);
	g->g_cost[sidx] = 0.0f;
	g->f_cost[sidx] = h_octile(sx - gx, sy - gy);
	g->heap[0] = 0;
	heap_push_or_decrease(g, sidx);

	while (g->heap[0] > 0) {
		int top = heap_pop(g);
		if (g->closed[top])
			continue;
		g->closed[top] = 1;
		if (top == gidx)
			break;
		int cx = top % GRID_W, cy = top / GRID_W;
		for (int dy = -1; dy <= 1; dy++)
			for (int dx = -1; dx <= 1; dx++) {
				if (dx == 0 && dy == 0)
					continue;
				int nx = cx + dx, ny = cy + dy;
				if (!cell_passable(g, nx, ny))
					continue;
				float step = (dx != 0 && dy != 0) ? SQRT2F : 1.0f;
				if (dx != 0 && dy != 0) {
					/* DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES */
					if (!cell_passable(g, cx + dx, cy) || !cell_passable(g, cx, cy + dy))
						continue;
				}
				int nidx = cell_idx(nx, ny);
				touch_cell(g, nidx, gen);
				if (g->closed[nidx])
					continue;
				float ng = g->g_cost[top] + step;
				if (ng < g->g_cost[nidx]) {
					g->g_cost[nidx] = ng;
					g->came_from[nidx] = top;
					g->f_cost[nidx] = ng + h_octile(nx - gx, ny - gy);
					heap_push_or_decrease(g, nidx);
				}
			}
	}
	if (g->came_from[gidx] < 0 && gidx != sidx)
		return 0;
	int n = 0;
	for (int c = gidx; c >= 0; c = g->came_from[c]) {
		if (n < max_out)
			out_cells[n] = c;
		n++;
	}
	int m = n < max_out ? n : max_out;
	for (int i = 0; i < m / 2; i++) {
		int32_t t = out_cells[i];
		out_cells[i] = out_cells[m - 1 - i];
		out_cells[m - 1 - i] = t;
	}
	return m;
}

/* ---------------- Path post-processing ---------------- */

static int smooth_path(NavGrid *g, V3 *path, int n) {
	if (n <= 2)
		return n;
	V3 *out = (V3 *)fn_mem_alloc(sizeof(V3) * n);
	int m = 0;
	out[m++] = path[0];
	int cur = 0;
	while (cur < n - 1) {
		int farthest = cur + 1;
		int stride = 2;
		while (farthest < n - 1) {
			int cand = cur + stride;
			if (cand > n - 1)
				cand = n - 1;
			if (!path_clear(g, path[cur], path[cand]))
				break;
			farthest = cand;
			if (stride >= 32)
				break;
			stride *= 2;
		}
		out[m++] = path[farthest];
		cur = farthest;
	}
	memcpy(path, out, sizeof(V3) * m);
	fn_mem_free(out);
	return m;
}

static V2i nearest_free_cell(NavGrid *g, V2i cell) {
	for (int radius = 1; radius < 10; radius++)
		for (int dx = -radius; dx <= radius; dx++)
			for (int dy = -radius; dy <= radius; dy++) {
				int adx = dx < 0 ? -dx : dx, ady = dy < 0 ? -dy : dy;
				if (adx != radius && ady != radius)
					continue;
				V2i cand = { cell.x + dx, cell.y + dy };
				if (!cell_blocked(g, cand))
					return cand;
			}
	return cell;
}

static void push_v3(GDExtensionVariantPtr arr_var, V3 v) {
	VarSlot elem, ret;
	GDExtensionCallError err;
	fn_variant_new_nil(&ret);
	var_from_vec3(&elem, &v);
	const GDExtensionConstVariantPtr argv[1] = { (GDExtensionConstVariantPtr)&elem };
	fn_variant_call(arr_var, &sn_push_back, argv, 1, &ret, &err);
	fn_variant_destroy(&ret);
	fn_variant_destroy(&elem);
}

/* ---------------- River cells ---------------- */

static void block_river_cells(NavGrid *g, GDExtensionVariantPtr rivers_var) {
	if (fn_variant_get_type(rivers_var) != GDEXTENSION_VARIANT_TYPE_ARRAY)
		return;
	TypeSlot arr_h;
	array_handle(rivers_var, &arr_h);
	int64_t n = array_len(rivers_var);
	for (int64_t i = 0; i < n; i++) {
		GDExtensionVariantPtr seg = fn_array_index(arr_h.b, (GDExtensionInt)i);
		if (!seg || fn_variant_get_type(seg) != GDEXTENSION_VARIANT_TYPE_DICTIONARY)
			continue;
		V2 size = { 0, 0 };
		V3 center = { 0, 0, 0 };
		dict_vec2(seg, "size", &size);
		dict_vec3(seg, "center", &center);
		float yaw = dict_float(seg, "yaw", 0.0f) * (float)M_PI / 180.0f;
		float along_x = cosf(yaw), along_z = -sinf(yaw);
		float across_x = sinf(yaw), across_z = cosf(yaw);
		float margin = 1.2f + CELL_SIZE * 0.71f;
		int big = size.x >= 60.0f;
		float half_l = size.x * (big ? 0.425f : 0.5f) + margin;
		float half_w = size.y * (big ? 0.425f : 0.5f) + margin;
		int steps_l = (int)ceilf(half_l * 4.0f / CELL_SIZE) + 1;
		int steps_w = (int)ceilf(half_w * 4.0f / CELL_SIZE) + 1;
		for (int a = 0; a <= steps_l; a++) {
			float la = -half_l + 2.0f * half_l * ((float)a / (float)steps_l);
			for (int b = 0; b <= steps_w; b++) {
				float lw = -half_w + 2.0f * half_w * ((float)b / (float)steps_w);
				if (big) {
					float ef = la / half_l, es = lw / half_w;
					if (ef * ef + es * es > 1.0f)
						continue;
				}
				float wx = center.x + along_x * la + across_x * lw;
				float wz = center.z + along_z * la + across_z * lw;
				V2i c = world_to_grid((V3){ wx, 0.0f, wz });
				if (c.x >= 0 && c.x < GRID_W && c.y >= 0 && c.y < GRID_H)
					g->blocked[cell_idx(c.x, c.y)] = 1;
			}
		}
	}
	dtor_arr(&arr_h);
}

/* ---------------- Doorway geometry (ports of Main._is_in_doorway_passage /
 * _is_in_barn_doorway_passage) ---------------- */

static int in_doorway_passage(V3 p, V3 origin) {
	float lx = p.x - origin.x, lz = p.z - origin.z;
	return fabsf(lx) <= 1.5f && lz >= -5.2f && lz <= 5.2f;
}

static int in_barn_doorway_passage(V3 p, V3 pos, float front_x, float front_w,
		float back_x, float back_w, float half_d) {
	if (fabsf(p.x - front_x) <= front_w * 0.5f + 0.5f &&
	    p.z <= pos.z + 1.0f && p.z >= pos.z - half_d - 2.0f)
		return 1;
	if (fabsf(p.x - back_x) <= back_w * 0.5f + 0.5f &&
	    p.z >= pos.z - 1.0f && p.z <= pos.z + half_d + 2.0f)
		return 1;
	return 0;
}

/* ---------------- Instance lifecycle ---------------- */

static NavGrid *nav_alloc(void) {
	NavGrid *g = (NavGrid *)fn_mem_alloc(sizeof(NavGrid));
	memset(g, 0, sizeof(*g));
	g->blocked = (uint8_t *)fn_mem_alloc(GRID_N);
	g->door_open = (uint8_t *)fn_mem_alloc(GRID_N);
	memset(g->blocked, 0, GRID_N);
	memset(g->door_open, 0, GRID_N);
	g->queue = (int32_t *)fn_mem_alloc(sizeof(int32_t) * GRID_N);
	g->g_cost = (float *)fn_mem_alloc(sizeof(float) * GRID_N);
	g->f_cost = (float *)fn_mem_alloc(sizeof(float) * GRID_N);
	g->came_from = (int32_t *)fn_mem_alloc(sizeof(int32_t) * GRID_N);
	g->closed = (uint8_t *)fn_mem_alloc(GRID_N);
	g->seen_gen = (uint32_t *)fn_mem_alloc(sizeof(uint32_t) * GRID_N);
	memset(g->seen_gen, 0, sizeof(uint32_t) * GRID_N);
	g->search_gen = 0;
	g->heap = (int32_t *)fn_mem_alloc(sizeof(int32_t) * (GRID_N + 2));
	g->heap_pos = (int32_t *)fn_mem_alloc(sizeof(int32_t) * GRID_N);
	memset(g->heap_pos, 0, sizeof(int32_t) * GRID_N);
	return g;
}

static void nav_dispose(NavGrid *g) {
	if (!g)
		return;
	if (g->blocked) fn_mem_free(g->blocked);
	if (g->door_open) fn_mem_free(g->door_open);
	if (g->queue) fn_mem_free(g->queue);
	if (g->g_cost) fn_mem_free(g->g_cost);
	if (g->f_cost) fn_mem_free(g->f_cost);
	if (g->came_from) fn_mem_free(g->came_from);
	if (g->closed) fn_mem_free(g->closed);
	if (g->seen_gen) fn_mem_free(g->seen_gen);
	if (g->heap) fn_mem_free(g->heap);
	if (g->heap_pos) fn_mem_free(g->heap_pos);
	nav_free_regions(g);
	fn_mem_free(g);
}

/* ---------------- GDExtension method bodies ---------------- */

static void nav_build_impl(NavGrid *g, GDExtensionVariantPtr blockers_var, GDExtensionVariantPtr rivers_var) {
	memset(g->blocked, 0, GRID_N);
	memset(g->door_open, 0, GRID_N);
	nav_free_regions(g);

	TypeSlot arr_h;
	array_handle(blockers_var, &arr_h);
	int64_t n = array_len(blockers_var);
	for (int64_t i = 0; i < n; i++) {
		GDExtensionVariantPtr blocker = fn_array_index(arr_h.b, (GDExtensionInt)i);
		if (!blocker || fn_variant_get_type(blocker) != GDEXTENSION_VARIANT_TYPE_DICTIONARY)
			continue;
		V3 pos = { 0, 0, 0 };
		dict_vec3(blocker, "pos", &pos);
		float radius = dict_float(blocker, "radius", 1.8f);
		R2 bounds;
		if (dict_rect2(blocker, "house_bounds", &bounds)) {
			float ex = bounds.px - 3.5f, ey = bounds.py - 3.5f;
			float esx = bounds.sx + 7.0f, esy = bounds.sy + 7.0f;
			V2i c0 = world_to_grid((V3){ ex, 0.0f, ey });
			V2i c1 = world_to_grid((V3){ ex + esx, 0.0f, ey + esy });
			for (int gx = c0.x; gx <= c1.x; gx++)
				for (int gy = c0.y; gy <= c1.y; gy++)
					if (gx >= 0 && gx < GRID_W && gy >= 0 && gy < GRID_H)
						g->blocked[cell_idx(gx, gy)] = 1;
			continue;
		}
		V2i center = world_to_grid(pos);
		int cell_radius = (int)ceilf(radius / CELL_SIZE) + 1;
		for (int dx = -cell_radius; dx <= cell_radius; dx++)
			for (int dy = -cell_radius; dy <= cell_radius; dy++) {
				V2i cell = { center.x + dx, center.y + dy };
				if (cell.x < 0 || cell.x >= GRID_W || cell.y < 0 || cell.y >= GRID_H)
					continue;
				V3 w = grid_to_world(cell);
				float ddx = w.x - pos.x, ddz = w.z - pos.z;
				if (sqrtf(ddx * ddx + ddz * ddz) <= radius)
					g->blocked[cell_idx(cell.x, cell.y)] = 1;
			}
	}
	dtor_arr(&arr_h);
	block_river_cells(g, rivers_var);
	build_regions(g);
	g->built = 1;
}

static int call_door_pred_v3(GDExtensionVariantPtr fn_var, V3 world_pos, V3 origin) {
	VarSlot a0, a1, ret;
	GDExtensionCallError err;
	fn_variant_new_nil(&ret);
	var_from_vec3(&a0, &world_pos);
	var_from_vec3(&a1, &origin);
	const GDExtensionConstVariantPtr argv[2] = { &a0, &a1 };
	fn_variant_call(fn_var, &sn_call, argv, 2, &ret, &err);
	int res = 0;
	if (err.error == GDEXTENSION_CALL_OK && fn_variant_get_type(&ret) == GDEXTENSION_VARIANT_TYPE_BOOL) {
		GDExtensionBool b = 0;
		var_to_bool(&b, &ret);
		res = b ? 1 : 0;
	}
	fn_variant_destroy(&ret);
	fn_variant_destroy(&a1);
	fn_variant_destroy(&a0);
	return res;
}

static int call_barn_pred(GDExtensionVariantPtr fn_var, V3 world_pos, GDExtensionVariantPtr blocker_var) {
	VarSlot a0, ret;
	GDExtensionCallError err;
	fn_variant_new_nil(&ret);
	var_from_vec3(&a0, &world_pos);
	const GDExtensionConstVariantPtr argv[2] = { &a0, blocker_var };
	fn_variant_call(fn_var, &sn_call, argv, 2, &ret, &err);
	int res = 0;
	if (err.error == GDEXTENSION_CALL_OK && fn_variant_get_type(&ret) == GDEXTENSION_VARIANT_TYPE_BOOL) {
		GDExtensionBool b = 0;
		var_to_bool(&b, &ret);
		res = b ? 1 : 0;
	}
	fn_variant_destroy(&ret);
	fn_variant_destroy(&a0);
	return res;
}

static void nav_update_door_cache_impl(NavGrid *g, GDExtensionVariantPtr blockers_var,
		GDExtensionVariantPtr fn_doorway, GDExtensionVariantPtr fn_barn_doorway) {
	TypeSlot arr_h;
	array_handle(blockers_var, &arr_h);
	int64_t n = array_len(blockers_var);
	uint8_t *prev = (uint8_t *)fn_mem_alloc(GRID_N);
	memcpy(prev, g->door_open, GRID_N);
	memset(g->door_open, 0, GRID_N);
	int has_door_fn = fn_doorway && fn_variant_get_type(fn_doorway) == GDEXTENSION_VARIANT_TYPE_CALLABLE;
	int has_barn_fn = fn_barn_doorway && fn_variant_get_type(fn_barn_doorway) == GDEXTENSION_VARIANT_TYPE_CALLABLE;

	for (int64_t i = 0; i < n; i++) {
		GDExtensionVariantPtr blocker = fn_array_index(arr_h.b, (GDExtensionInt)i);
		if (!blocker || fn_variant_get_type(blocker) != GDEXTENSION_VARIANT_TYPE_DICTIONARY)
			continue;
		int barn_open = dict_bool(blocker, "barn_door_always_open");
		int door_open = barn_open || dict_bool(blocker, "door_open");
		if (!door_open) {
			VarSlot door_var;
			if (dict_get(blocker, "door", &door_var)) {
				if (fn_variant_get_type(&door_var) == GDEXTENSION_VARIANT_TYPE_OBJECT)
					door_open = dict_bool(&door_var, "is_open");
				fn_variant_destroy(&door_var);
			}
		}
		if (!door_open)
			continue;
		V3 pos = { 0, 0, 0 };
		dict_vec3(blocker, "pos", &pos);
		R2 bounds;
		if (dict_rect2(blocker, "house_bounds", &bounds)) {
			float ex = bounds.px - 3.5f, ey = bounds.py - 3.5f;
			float esx = bounds.sx + 7.0f, esy = bounds.sy + 7.0f;
			V2i c0 = world_to_grid((V3){ ex, 0.0f, ey });
			V2i c1 = world_to_grid((V3){ ex + esx, 0.0f, ey + esy });
			float front_x = dict_float(blocker, "front_door_x", pos.x);
			float front_w = dict_float(blocker, "front_door_w", 2.0f);
			float back_x = dict_float(blocker, "back_door_x", pos.x);
			float back_w = dict_float(blocker, "back_door_w", 2.0f);
			float half_d = bounds.sy * 0.5f;
			for (int gx = c0.x; gx <= c1.x; gx++)
				for (int gy = c0.y; gy <= c1.y; gy++) {
					if (gx < 0 || gx >= GRID_W || gy < 0 || gy >= GRID_H)
						continue;
					int idx = cell_idx(gx, gy);
					if (!g->blocked[idx])
						continue;
					V3 w = grid_to_world((V2i){ gx, gy });
					if (barn_open) {
						int ok = has_barn_fn ? call_barn_pred(fn_barn_doorway, w, blocker)
						                     : in_barn_doorway_passage(w, pos, front_x, front_w, back_x, back_w, half_d);
						if (ok)
							g->door_open[idx] = 1;
					} else {
						int ok = has_door_fn ? call_door_pred_v3(fn_doorway, w, pos)
						                     : in_doorway_passage(w, pos);
						if (ok)
							g->door_open[idx] = 1;
					}
				}
			continue;
		}
		float radius = dict_float(blocker, "radius", 1.8f);
		V2i center = world_to_grid(pos);
		int cell_radius = (int)ceilf(radius / CELL_SIZE) + 1;
		for (int dx = -cell_radius; dx <= cell_radius; dx++)
			for (int dy = -cell_radius; dy <= cell_radius; dy++) {
				V2i cell = { center.x + dx, center.y + dy };
				if (cell.x < 0 || cell.x >= GRID_W || cell.y < 0 || cell.y >= GRID_H)
					continue;
				int idx = cell_idx(cell.x, cell.y);
				if (!g->blocked[idx])
					continue;
				V3 w = grid_to_world(cell);
				float lx = w.x - pos.x, lz = w.z - pos.z;
				if (fabsf(lx) <= 1.5f && lz >= -5.2f && lz <= 10.0f)
					g->door_open[idx] = 1;
			}
	}
	if (g->built && memcmp(prev, g->door_open, GRID_N) != 0)
		update_region_groups(g);
	fn_mem_free(prev);
	dtor_arr(&arr_h);
}

/* ---------------- Method call wrappers ---------------- */

static void mcall_build(void *ud, GDExtensionClassInstancePtr inst,
		const GDExtensionConstVariantPtr *args, GDExtensionInt argc,
		GDExtensionVariantPtr ret, GDExtensionCallError *err) {
	(void)ud; (void)ret;
	if (argc < 2) {
		err->error = GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS;
		err->expected = 2;
		return;
	}
	if (fn_variant_get_type(args[0]) != GDEXTENSION_VARIANT_TYPE_ARRAY ||
	    fn_variant_get_type(args[1]) != GDEXTENSION_VARIANT_TYPE_ARRAY) {
		err->error = GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;
		err->argument = 0;
		return;
	}
	nav_build_impl((NavGrid *)inst, (GDExtensionVariantPtr)args[0], (GDExtensionVariantPtr)args[1]);
}

static void mcall_update_door_cache(void *ud, GDExtensionClassInstancePtr inst,
		const GDExtensionConstVariantPtr *args, GDExtensionInt argc,
		GDExtensionVariantPtr ret, GDExtensionCallError *err) {
	(void)ud; (void)ret;
	if (argc < 1) {
		err->error = GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS;
		err->expected = 1;
		return;
	}
	if (fn_variant_get_type(args[0]) != GDEXTENSION_VARIANT_TYPE_ARRAY) {
		err->error = GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;
		err->argument = 0;
		return;
	}
	GDExtensionVariantPtr fn1 = argc >= 2 ? (GDExtensionVariantPtr)args[1] : NULL;
	GDExtensionVariantPtr fn2 = argc >= 3 ? (GDExtensionVariantPtr)args[2] : NULL;
	nav_update_door_cache_impl((NavGrid *)inst, (GDExtensionVariantPtr)args[0], fn1, fn2);
}

static void mcall_world_to_grid(void *ud, GDExtensionClassInstancePtr inst,
		const GDExtensionConstVariantPtr *args, GDExtensionInt argc,
		GDExtensionVariantPtr ret, GDExtensionCallError *err) {
	(void)ud; (void)inst;
	if (argc < 1 || fn_variant_get_type(args[0]) != GDEXTENSION_VARIANT_TYPE_VECTOR3) {
		err->error = GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;
		err->argument = 0;
		return;
	}
	V3 p;
	var_to_v3(&p, (GDExtensionVariantPtr)args[0]);
	V2i c = world_to_grid(p);
	var_from_v2i(ret, &c);
}

static void mcall_grid_to_world(void *ud, GDExtensionClassInstancePtr inst,
		const GDExtensionConstVariantPtr *args, GDExtensionInt argc,
		GDExtensionVariantPtr ret, GDExtensionCallError *err) {
	(void)ud; (void)inst;
	if (argc < 1 || fn_variant_get_type(args[0]) != GDEXTENSION_VARIANT_TYPE_VECTOR2I) {
		err->error = GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;
		err->argument = 0;
		return;
	}
	V2i c;
	var_to_v2i(&c, (GDExtensionVariantPtr)args[0]);
	V3 w = grid_to_world(c);
	var_from_vec3(ret, &w);
}

static void mcall_is_path_clear(void *ud, GDExtensionClassInstancePtr inst,
		const GDExtensionConstVariantPtr *args, GDExtensionInt argc,
		GDExtensionVariantPtr ret, GDExtensionCallError *err) {
	(void)ud;
	if (argc < 2 || fn_variant_get_type(args[0]) != GDEXTENSION_VARIANT_TYPE_VECTOR3 ||
	    fn_variant_get_type(args[1]) != GDEXTENSION_VARIANT_TYPE_VECTOR3) {
		err->error = GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;
		err->argument = 0;
		return;
	}
	V3 a, b;
	var_to_v3(&a, (GDExtensionVariantPtr)args[0]);
	var_to_v3(&b, (GDExtensionVariantPtr)args[1]);
	GDExtensionBool ok = path_clear((NavGrid *)inst, a, b) ? 1 : 0;
	var_from_bool(ret, &ok);
}

static void mcall_is_built(void *ud, GDExtensionClassInstancePtr inst,
		const GDExtensionConstVariantPtr *args, GDExtensionInt argc,
		GDExtensionVariantPtr ret, GDExtensionCallError *err) {
	(void)ud; (void)args; (void)argc; (void)err;
	GDExtensionBool b = ((NavGrid *)inst)->built ? 1 : 0;
	var_from_bool(ret, &b);
}

static void mcall_is_cell_blocked(void *ud, GDExtensionClassInstancePtr inst,
		const GDExtensionConstVariantPtr *args, GDExtensionInt argc,
		GDExtensionVariantPtr ret, GDExtensionCallError *err) {
	(void)ud;
	if (argc < 1 || fn_variant_get_type(args[0]) != GDEXTENSION_VARIANT_TYPE_VECTOR2I) {
		err->error = GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;
		err->argument = 0;
		return;
	}
	V2i c;
	var_to_v2i(&c, (GDExtensionVariantPtr)args[0]);
	GDExtensionBool b = cell_blocked((NavGrid *)inst, c) ? 1 : 0;
	var_from_bool(ret, &b);
}

static void mcall_find_path(void *ud, GDExtensionClassInstancePtr inst,
		const GDExtensionConstVariantPtr *args, GDExtensionInt argc,
		GDExtensionVariantPtr ret, GDExtensionCallError *err) {
	(void)ud;
	NavGrid *g = (NavGrid *)inst;
	if (argc < 2 || fn_variant_get_type(args[0]) != GDEXTENSION_VARIANT_TYPE_VECTOR3 ||
	    fn_variant_get_type(args[1]) != GDEXTENSION_VARIANT_TYPE_VECTOR3) {
		err->error = GDEXTENSION_CALL_ERROR_INVALID_ARGUMENT;
		err->argument = 0;
		return;
	}
	V3 start, goal;
	var_to_v3(&start, (GDExtensionVariantPtr)args[0]);
	var_to_v3(&goal, (GDExtensionVariantPtr)args[1]);

	fn_variant_construct(GDEXTENSION_VARIANT_TYPE_ARRAY, ret, NULL, 0, err);
	if (err->error != GDEXTENSION_CALL_OK)
		return;
	if (!g->built) {
		push_v3(ret, goal);
		return;
	}
	V2i sc = world_to_grid(start), gc = world_to_grid(goal);
	if (cell_blocked(g, gc))
		gc = nearest_free_cell(g, gc);
	if (cell_blocked(g, sc))
		sc = nearest_free_cell(g, sc);
	if (cell_blocked(g, sc) || cell_blocked(g, gc))
		return; /* empty array */
	if (sc.x == gc.x && sc.y == gc.y) {
		push_v3(ret, grid_to_world(gc));
		return;
	}
	gc = reachable_goal(g, sc, gc);
	V3 goal_w = grid_to_world(gc);
	if (path_clear(g, start, goal_w)) {
		push_v3(ret, goal_w);
		return;
	}
	int32_t *cells = g->queue;
	int n = astar(g, sc, gc, cells, GRID_N);
	if (n <= 0)
		return;
	V3 *path = (V3 *)fn_mem_alloc(sizeof(V3) * (n + 1));
	for (int i = 0; i < n; i++)
		path[i] = grid_to_world((V2i){ cells[i] % GRID_W, cells[i] / GRID_W });
	int pn = n;
	if (pn > 1 && path_clear(g, start, path[1])) {
		memmove(path, path + 1, sizeof(V3) * (pn - 1));
		pn--;
	}
	pn = smooth_path(g, path, pn);
	for (int i = 0; i < pn; i++)
		push_v3(ret, path[i]);
	fn_mem_free(path);
}

/* ---------------- Class create/free ---------------- */

static GDExtensionObjectPtr nav_create(void *ud, GDExtensionBool notify_postinit) {
	(void)ud; (void)notify_postinit;
	GDExtensionObjectPtr obj = fn_construct_object(&sn_parent);
	NavGrid *g = nav_alloc();
	fn_object_set_instance(obj, &sn_class, g);
	return obj;
}

static void nav_free_instance(void *ud, GDExtensionClassInstancePtr inst) {
	(void)ud;
	nav_dispose((NavGrid *)inst);
}

static GDExtensionClassCallVirtual nav_get_virtual(void *ud, GDExtensionConstStringNamePtr name, uint32_t hash) {
	(void)ud; (void)name; (void)hash;
	return NULL;
}

/* ---------------- Registration ---------------- */

static GDExtensionPropertyInfo arg_info(GDExtensionVariantType t) {
	GDExtensionPropertyInfo p;
	memset(&p, 0, sizeof(p));
	p.type = t;
	p.name = &sn_empty;
	p.class_name = &sn_empty;
	p.hint_string = &s_hint;
	return p;
}

static void register_method(TypeSlot *name_sn, GDExtensionClassMethodCall call,
		GDExtensionBool has_ret, GDExtensionVariantType ret_type,
		uint32_t arg_count, GDExtensionPropertyInfo *args_info) {
	GDExtensionPropertyInfo ret_info;
	memset(&ret_info, 0, sizeof(ret_info));
	ret_info.type = ret_type;
	ret_info.name = &sn_empty;
	ret_info.class_name = &sn_empty;
	ret_info.hint_string = &s_hint;
	GDExtensionClassMethodInfo mi;
	memset(&mi, 0, sizeof(mi));
	mi.name = name_sn;
	mi.call_func = call;
	mi.method_flags = GDEXTENSION_METHOD_FLAG_NORMAL;
	mi.has_return_value = has_ret;
	mi.return_value_info = has_ret ? &ret_info : NULL;
	mi.return_value_metadata = GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE;
	mi.argument_count = arg_count;
	mi.arguments_info = arg_count ? args_info : NULL;
	static GDExtensionClassMethodArgumentMetadata meta_none[8];
	mi.arguments_metadata = arg_count ? meta_none : NULL;
	fn_register_method(g_lib, &sn_class, &mi);
}

static void nav_initialize(void *ud, GDExtensionInitializationLevel level) {
	(void)ud;
	if (level != GDEXTENSION_INITIALIZATION_SCENE)
		return;

	GDExtensionClassCreationInfo6 ci;
	memset(&ci, 0, sizeof(ci));
	ci.is_exposed = 1;
	ci.create_instance_func = nav_create;
	ci.free_instance_func = nav_free_instance;
	ci.get_virtual_func = nav_get_virtual;
	fn_register_class(g_lib, &sn_class, &sn_parent, &ci);

	GDExtensionPropertyInfo arr_args[2];
	arr_args[0] = arg_info(GDEXTENSION_VARIANT_TYPE_ARRAY);
	arr_args[1] = arg_info(GDEXTENSION_VARIANT_TYPE_ARRAY);
	register_method(&sn_m_build, mcall_build, 0, GDEXTENSION_VARIANT_TYPE_NIL, 2, arr_args);

	GDExtensionPropertyInfo path_args[2];
	path_args[0] = arg_info(GDEXTENSION_VARIANT_TYPE_VECTOR3);
	path_args[1] = arg_info(GDEXTENSION_VARIANT_TYPE_VECTOR3);
	register_method(&sn_m_find_path, mcall_find_path, 1, GDEXTENSION_VARIANT_TYPE_ARRAY, 2, path_args);

	GDExtensionPropertyInfo cell_args[1];
	cell_args[0] = arg_info(GDEXTENSION_VARIANT_TYPE_VECTOR2I);
	register_method(&sn_m_is_blocked, mcall_is_cell_blocked, 1, GDEXTENSION_VARIANT_TYPE_BOOL, 1, cell_args);

	GDExtensionPropertyInfo door_args[3];
	door_args[0] = arg_info(GDEXTENSION_VARIANT_TYPE_ARRAY);
	door_args[1] = arg_info(GDEXTENSION_VARIANT_TYPE_CALLABLE);
	door_args[2] = arg_info(GDEXTENSION_VARIANT_TYPE_CALLABLE);
	register_method(&sn_m_update_door_cache, mcall_update_door_cache, 0, GDEXTENSION_VARIANT_TYPE_NIL, 3, door_args);

	register_method(&sn_m_is_built, mcall_is_built, 1, GDEXTENSION_VARIANT_TYPE_BOOL, 0, NULL);

	GDExtensionPropertyInfo v3_arg[1];
	v3_arg[0] = arg_info(GDEXTENSION_VARIANT_TYPE_VECTOR3);
	register_method(&sn_m_world_to_grid, mcall_world_to_grid, 1, GDEXTENSION_VARIANT_TYPE_VECTOR2I, 1, v3_arg);
	register_method(&sn_m_grid_to_world, mcall_grid_to_world, 1, GDEXTENSION_VARIANT_TYPE_VECTOR3, 1, cell_args);
	register_method(&sn_m_is_path_clear, mcall_is_path_clear, 1, GDEXTENSION_VARIANT_TYPE_BOOL, 2, path_args);
}

static void nav_deinitialize(void *ud, GDExtensionInitializationLevel level) {
	(void)ud;
	if (level != GDEXTENSION_INITIALIZATION_SCENE)
		return;
	sname_free(&sn_class);
	sname_free(&sn_parent);
	sname_free(&sn_empty);
	sname_free(&sn_m_build);
	sname_free(&sn_m_find_path);
	sname_free(&sn_m_is_blocked);
	sname_free(&sn_m_update_door_cache);
	sname_free(&sn_m_is_built);
	sname_free(&sn_m_world_to_grid);
	sname_free(&sn_m_grid_to_world);
	sname_free(&sn_m_is_path_clear);
	sname_free(&sn_size);
	sname_free(&sn_push_back);
	sname_free(&sn_call);
	dtor_string(&s_hint);
}

GDExtensionBool GDE_EXPORT lastday_nav_library_init(
		GDExtensionInterfaceGetProcAddress get_proc,
		GDExtensionClassLibraryPtr library,
		GDExtensionInitialization *r_initialization) {
	g_lib = library;

	fn_mem_alloc = (GDExtensionInterfaceMemAlloc)get_proc("mem_alloc");
	fn_mem_realloc = (GDExtensionInterfaceMemRealloc)get_proc("mem_realloc");
	fn_mem_free = (GDExtensionInterfaceMemFree)get_proc("mem_free");
	fn_print_error = (GDExtensionInterfacePrintError)get_proc("print_error");
	fn_variant_new_nil = (GDExtensionInterfaceVariantNewNil)get_proc("variant_new_nil");
	fn_variant_destroy = (GDExtensionInterfaceVariantDestroy)get_proc("variant_destroy");
	fn_variant_call = (GDExtensionInterfaceVariantCall)get_proc("variant_call");
	fn_variant_get = (GDExtensionInterfaceVariantGet)get_proc("variant_get");
	fn_variant_get_type = (GDExtensionInterfaceVariantGetType)get_proc("variant_get_type");
	fn_variant_construct = (GDExtensionInterfaceVariantConstruct)get_proc("variant_construct");
	fn_get_v_from_t = (GDExtensionInterfaceGetVariantFromTypeConstructor)get_proc("get_variant_from_type_constructor");
	fn_get_v_to_t = (GDExtensionInterfaceGetVariantToTypeConstructor)get_proc("get_variant_to_type_constructor");
	fn_get_v_dtor = (GDExtensionInterfaceVariantGetPtrDestructor)get_proc("variant_get_ptr_destructor");
	fn_string_new = (GDExtensionInterfaceStringNewWithLatin1Chars)get_proc("string_new_with_latin1_chars");
	fn_sname_new = (GDExtensionInterfaceStringNameNewWithLatin1Chars)get_proc("string_name_new_with_latin1_chars");
	fn_array_index = (GDExtensionInterfaceArrayOperatorIndexConst)get_proc("array_operator_index_const");
	fn_construct_object = (GDExtensionInterfaceClassdbConstructObject3)get_proc("classdb_construct_object3");
	fn_register_class = (GDExtensionInterfaceClassdbRegisterExtensionClass6)get_proc("classdb_register_extension_class6");
	fn_register_method = (GDExtensionInterfaceClassdbRegisterExtensionClassMethod)get_proc("classdb_register_extension_class_method");
	fn_object_set_instance = (GDExtensionInterfaceObjectSetInstance)get_proc("object_set_instance");

	if (!fn_mem_alloc || !fn_mem_free || !fn_variant_call || !fn_variant_get ||
	    !fn_variant_construct || !fn_register_class || !fn_register_method ||
	    !fn_construct_object || !fn_object_set_instance || !fn_array_index ||
	    !fn_string_new || !fn_sname_new || !fn_variant_destroy)
		return 0;

	var_from_bool = fn_get_v_from_t(GDEXTENSION_VARIANT_TYPE_BOOL);
	var_from_string = fn_get_v_from_t(GDEXTENSION_VARIANT_TYPE_STRING);
	var_from_vec3 = fn_get_v_from_t(GDEXTENSION_VARIANT_TYPE_VECTOR3);
	var_from_v2i = fn_get_v_from_t(GDEXTENSION_VARIANT_TYPE_VECTOR2I);
	var_to_bool = fn_get_v_to_t(GDEXTENSION_VARIANT_TYPE_BOOL);
	var_to_int = fn_get_v_to_t(GDEXTENSION_VARIANT_TYPE_INT);
	var_to_float = fn_get_v_to_t(GDEXTENSION_VARIANT_TYPE_FLOAT);
	var_to_v2 = fn_get_v_to_t(GDEXTENSION_VARIANT_TYPE_VECTOR2);
	var_to_v2i = fn_get_v_to_t(GDEXTENSION_VARIANT_TYPE_VECTOR2I);
	var_to_v3 = fn_get_v_to_t(GDEXTENSION_VARIANT_TYPE_VECTOR3);
	var_to_r2 = fn_get_v_to_t(GDEXTENSION_VARIANT_TYPE_RECT2);
	var_to_arr = fn_get_v_to_t(GDEXTENSION_VARIANT_TYPE_ARRAY);
	dtor_string = fn_get_v_dtor(GDEXTENSION_VARIANT_TYPE_STRING);
	dtor_sname = fn_get_v_dtor(GDEXTENSION_VARIANT_TYPE_STRING_NAME);
	dtor_arr = fn_get_v_dtor(GDEXTENSION_VARIANT_TYPE_ARRAY);

	sname_make(&sn_class, "LastDayNav");
	sname_make(&sn_parent, "RefCounted");
	sname_make(&sn_empty, "");
	sname_make(&sn_m_build, "build");
	sname_make(&sn_m_find_path, "find_path");
	sname_make(&sn_m_is_blocked, "is_cell_blocked");
	sname_make(&sn_m_update_door_cache, "update_door_cache");
	sname_make(&sn_m_is_built, "is_built");
	sname_make(&sn_m_world_to_grid, "world_to_grid");
	sname_make(&sn_m_grid_to_world, "grid_to_world");
	sname_make(&sn_m_is_path_clear, "_is_path_clear");
	sname_make(&sn_size, "size");
	sname_make(&sn_push_back, "push_back");
	sname_make(&sn_call, "call");
	fn_string_new(&s_hint, "");

	r_initialization->userdata = NULL;
	r_initialization->initialize = nav_initialize;
	r_initialization->deinitialize = nav_deinitialize;
	r_initialization->minimum_initialization_level = GDEXTENSION_INITIALIZATION_SCENE;
	return 1;
}
