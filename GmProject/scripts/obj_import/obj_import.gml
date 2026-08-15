/// obj_import(filename)
/// @arg filename
/// @desc Parses a Wavefront .obj model file (and its .mtl material file, if any).
///   Returns a ds_map with:
///     vertices  : array of [x, y, z]        (OBJ space, Y-up)
///     uvs       : array of [u, v]
///     normals   : array of [x, y, z]
///     faces     : array of [[vi, ti, ni], [vi, ti, ni], [vi, ti, ni]]
///                 (triangulated; indices are 1-based, 0 = missing)
///     face_mats : array of material name per face (parallel to faces)
///     materials : ds_map material name -> texture file name
///   Returns null if the file is missing or empty.

function obj_import(fn)
{
	var txt = file_text_contents(fn)
	if (string_length(txt) = 0)
		return null
	
	var parsed = ds_map_create()
	parsed[?"materials"] = ds_map_create()
	
	var lines = string_split(txt, "\n")
	var nlines = array_length(lines)
	
	// ---- Find the material library ----
	var mtlname = ""
	for (var i = 0; i < nlines; i++)
	{
		var toks = obj_tokenize(lines[i])
		if (array_length(toks) > 0 && toks[0] = "mtllib")
		{
			mtlname = toks[1]
			break
		}
	}
	
	// ---- Load the .mtl file (material name -> texture) ----
	var materials = parsed[?"materials"]
	if (mtlname != "")
	{
		var mtl_txt = file_text_contents(filename_dir(fn) + "/" + mtlname)
		if (string_length(mtl_txt) > 0)
		{
			var mtl_lines = string_split(mtl_txt, "\n")
			var mtl_n = array_length(mtl_lines)
			var cur = ""
			for (var i = 0; i < mtl_n; i++)
			{
				var toks = obj_tokenize(mtl_lines[i])
				var tn = array_length(toks)
				if (tn = 0)
					continue
				if (toks[0] = "newmtl")
					cur = toks[1]
				else if (toks[0] = "map_Kd" && cur != "")
					materials[?cur] = (tn > 1 ? filename_name(toks[1]) : "")
			}
		}
	}
	
	// ---- Parse geometry ----
	var varr = array_create(0)
	var vn = 0
	var vtarr = array_create(0)
	var vtn = 0
	var vnarr = array_create(0)
	var vnn = 0
	var farr = array_create(0)
	var fnn = 0
	var fmarr = array_create(0)
	var curmat = ""
	
	for (var i = 0; i < nlines; i++)
	{
		var toks = obj_tokenize(lines[i])
		var tn = array_length(toks)
		if (tn = 0)
			continue
		
		var t0 = toks[0]
		if (t0 = "v" && tn >= 4)
			varr[vn++] = [string_get_real(toks[1], 0), string_get_real(toks[2], 0), string_get_real(toks[3], 0)]
		else if (t0 = "vt" && tn >= 3)
			vtarr[vtn++] = [string_get_real(toks[1], 0), string_get_real(toks[2], 0)]
		else if (t0 = "vn" && tn >= 4)
			vnarr[vnn++] = [string_get_real(toks[1], 0), string_get_real(toks[2], 0), string_get_real(toks[3], 0)]
		else if (t0 = "usemtl")
			curmat = (tn > 1 ? toks[1] : "")
		else if (t0 = "f")
		{
			// Gather face corners (tris, quads and n-gons are supported)
			var corners = array_create(0)
			var cn = 0
			for (var j = 1; j < tn; j++)
			{
				var parts = string_split(toks[j], "/")
				var plen = array_length(parts)
				var vi = string_get_real(parts[0], 0)
				var ti = (plen > 1 ? string_get_real(parts[1], 0) : 0)
				var ni = (plen > 2 ? string_get_real(parts[2], 0) : 0)
				corners[cn++] = [vi, ti, ni]
			}
			
			// Fan triangulation
			if (cn >= 3)
			{
				for (var j = 1; j < cn - 1; j++)
				{
					farr[fnn] = [corners[0], corners[j], corners[j + 1]]
					fmarr[fnn] = curmat
					fnn++
				}
			}
		}
	}
	
	// Commit arrays to the map
	parsed[?"vertices"] = varr
	parsed[?"uvs"] = vtarr
	parsed[?"normals"] = vnarr
	parsed[?"faces"] = farr
	parsed[?"face_mats"] = fmarr
	parsed[?"vertex_count"] = vn
	parsed[?"face_count"] = fnn
	
	return parsed
}

/// obj_tokenize(string)
/// @desc Splits a line into non-empty tokens separated by whitespace (space, tab, CR).

function obj_tokenize(str)
{
	var arr = array_create(0)
	var n = 0
	var i = 1
	var len = string_length(str)
	while (i <= len)
	{
		// Skip whitespace
		while (i <= len && obj_is_space(string_char_at(str, i)))
			i++
		if (i > len)
			break
		
		// Read token
		var start = i
		while (i <= len && !obj_is_space(string_char_at(str, i)))
			i++
		arr[n++] = string_copy(str, start, i - start)
	}
	return arr
}

/// obj_is_space(char)
/// @desc Returns true if the character is whitespace (space, tab, carriage return).

function obj_is_space(c)
{
	var o = ord(c)
	return (o = 32 || o = 9 || o = 13)
}
