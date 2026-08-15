/// obj_mesh_to_mimodel(parsed, outfn, [compress])
/// @arg parsed   - ds_map returned by obj_import()
/// @arg outfn    - output .mimodel file path
/// @arg compress - optional; when true (default) decimates meshes with more than 10000 triangles
/// @desc Converts parsed OBJ data into a Mine-imator .mimodel file that uses the new "mesh" shape type.
///   Returns true on success, false if the model had no faces.

function obj_mesh_to_mimodel(parsed, outfn, compress = true)
{
	var varr = parsed[?"vertices"]
	var vtarr = parsed[?"uvs"]
	var vnarr = parsed[?"normals"]
	var farr = parsed[?"faces"]
	var fmarr = parsed[?"face_mats"]
	var materials = parsed[?"materials"]
	
	var tri_count = array_length(farr)
	if (tri_count = 0)
		return false
	
	// ---- Build a flat vertex list (internal Mine-imator space, Z-up) ----
	// Each vertex is [x, y, z, nx, ny, nz, u, v].
	// OBJ (Y-up) -> internal (Z-up): x'=x, y'=z, z'=-y  (a proper rotation, keeps winding).
	var verts = array_create(0)
	var vn = 0
	var minx = no_limit, miny = no_limit, minz = no_limit
	var maxx = -no_limit, maxy = -no_limit, maxz = -no_limit
	
	for (var i = 0; i < tri_count; i++)
	{
		var tri = farr[i]
		for (var j = 0; j < 3; j++)
		{
			var corner = tri[j]
			var vi = corner[0]
			var ti = corner[1]
			var ni = corner[2]
			
			// Position
			var ox = 0, oy = 0, oz = 0
			if (vi > 0 && vi <= array_length(varr))
			{
				var p = varr[vi - 1]
				ox = p[0]; oy = p[1]; oz = p[2]
			}
			var ix = ox
			var iy = oz
			var iz = -oy
			
			// Normal
			var nxn = 0, nyn = 0, nzn = 0
			if (ni > 0 && ni <= array_length(vnarr))
			{
				var np = vnarr[ni - 1]
				nxn = np[0]; nyn = np[1]; nzn = np[2]
			}
			var inx = nxn
			var iny = nzn
			var inz = -nyn
			
			// UV (flip V: OBJ origin is bottom-left, textures are top-left)
			var u = 0, v = 0
			if (ti > 0 && ti <= array_length(vtarr))
			{
				var t = vtarr[ti - 1]
				u = t[0]
				v = 1 - t[1]
			}
			
			verts[vn++] = [ix, iy, iz, inx, iny, inz, u, v]
			
			if (ix < minx) minx = ix
			if (ix > maxx) maxx = ix
			if (iy < miny) miny = iy
			if (iy > maxy) maxy = iy
			if (iz < minz) minz = iz
			if (iz > maxz) maxz = iz
		}
	}
	
	// ---- Optional compression (reduces triangle count for heavy models) ----
	if (compress && tri_count > 10000)
		verts = obj_mesh_compress(verts, 10000)
	
	// ---- Texture (first material that references a texture) ----
	var texture = ""
	if (tri_count > 0 && ds_map_exists(materials, fmarr[0]))
		texture = materials[?fmarr[0]]
	
	// ---- Write .mimodel JSON ----
	var name = filename_change_ext(filename_name(outfn), "")
	
	json_save_start(outfn)
	json_save_object_start()
	json_save_var("name", name)
	json_save_var("texture", texture)
	json_save_var("texture_size", [1, 1])
	json_save_array_start("parts")
	json_save_object_start()
	json_save_var("name", "part")
	json_save_var("position", [0, 0, 0])
	json_save_var("rotation", [0, 0, 0])
	json_save_var("scale", [1, 1, 1])
	json_save_array_start("shapes")
	json_save_object_start()
	json_save_var("type", "mesh")
	json_save_var("texture", texture)
	json_save_var("texture_size", [1, 1])
	json_save_var("uv", [0, 0])
	json_save_array_start("vertices")
	for (var i = 0; i < array_length(verts); i++)
		json_save_array_value(verts[i])
	json_save_array_done()
	json_save_object_done()
	json_save_array_done()
	json_save_object_done()
	json_save_array_done()
	json_save_object_done()
	json_save_done()
	
	log("Converted OBJ to .mimodel with " + string(array_length(verts) div 3) + " triangles")
	
	return true
}
