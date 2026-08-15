/// obj_mesh_compress(verts, target_triangles)
/// @arg verts   - flat vertex array; every 3 entries form one triangle,
///                 each entry is [x, y, z, nx, ny, nz, u, v]
/// @arg target_triangles - desired maximum triangle count
/// @desc Compresses a mesh using vertex clustering (positions are quantized to a grid,
///   all vertices in a cell are welded, degenerate triangles are dropped). This reduces
///   both the vertex and triangle count while keeping the result close to the original.
///   Returns a new flat vertex array.

function obj_mesh_compress(verts, target)
{
	var n = array_length(verts)
	var ntris = n div 3
	if (ntris <= target || target < 1)
		return verts
	
	// Bounding box
	var minx = no_limit, miny = no_limit, minz = no_limit
	var maxx = -no_limit, maxy = -no_limit, maxz = -no_limit
	for (var i = 0; i < n; i++)
	{
		var v = verts[i]
		if (v[0] < minx) minx = v[0]
		if (v[0] > maxx) maxx = v[0]
		if (v[1] < miny) miny = v[1]
		if (v[1] > maxy) maxy = v[1]
		if (v[2] < minz) minz = v[2]
		if (v[2] > maxz) maxz = v[2]
	}
	
	var sx = maxx - minx
	var sy = maxy - miny
	var sz = maxz - minz
	if (sx < 0.00001) sx = 0.00001
	if (sy < 0.00001) sy = 0.00001
	if (sz < 0.00001) sz = 0.00001
	
	// Cluster with an increasingly coarse grid until we reach the target.
	var out = verts
	var grid = max(2, round(power(target, 1.0 / 3.0)))
	for (var iter = 0; iter < 5; iter++)
	{
		if (array_length(out) div 3 <= target)
			break
		out = obj_mesh_cluster(out, grid, minx, miny, minz, sx, sy, sz)
		grid = max(grid + 1, round(grid * 1.5))
	}
	
	return out
}

/// obj_mesh_cluster(verts, grid, minx, miny, minz, sx, sy, sz)
/// @desc Internal: one vertex-clustering pass over the flat vertex array.

function obj_mesh_cluster(verts, grid, minx, miny, minz, sx, sy, sz)
{
	var n = array_length(verts)
	var cx = grid / sx
	var cy = grid / sy
	var cz = grid / sz
	
	var keymap = ds_map_create()
	var clusters = ds_list_create()
	var index = array_create(n)
	
	for (var i = 0; i < n; i++)
	{
		var v = verts[i]
		var gx = floor((v[0] - minx) * cx)
		var gy = floor((v[1] - miny) * cy)
		var gz = floor((v[2] - minz) * cz)
		if (gx < 0) gx = 0
		if (gy < 0) gy = 0
		if (gz < 0) gz = 0
		if (gx > grid) gx = grid
		if (gy > grid) gy = grid
		if (gz > grid) gz = grid
		
		var key = string(gx) + "," + string(gy) + "," + string(gz)
		if (ds_map_exists(keymap, key))
			index[i] = keymap[?key]
		else
		{
			var ci = ds_list_size(clusters)
			keymap[?key] = ci
			ds_list_add(clusters, v)
			index[i] = ci
		}
	}
	
	var out = array_create(0)
	var on = 0
	for (var i = 0; i < n; i += 3)
	{
		var a = index[i]
		var b = index[i + 1]
		var c = index[i + 2]
		// Skip degenerate triangles (collapsed to a point or a line)
		if (a = b || b = c || a = c)
			continue
		out[on++] = clusters[|a]
		out[on++] = clusters[|b]
		out[on++] = clusters[|c]
	}
	
	ds_map_destroy(keymap)
	ds_list_destroy(clusters)
	
	return out
}
