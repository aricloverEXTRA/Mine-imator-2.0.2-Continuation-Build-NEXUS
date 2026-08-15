/// model_shape_generate_mesh(bend)
/// @arg bend
/// @desc Generates a mesh shape (OBJ import) transformed by scale and rotation.
///   Vertices are read from the instance's flat `mesh_vertices` ds_list of reals,
///   interleaved as [x, y, z, nx, ny, nz, u, v] in internal (Z-up) space.
///   Mesh shapes are non-bendable in this version.

function model_shape_generate_mesh(bend)
{
	// Rotation matrix (matches the block generator; position is applied at render)
	var mat = matrix_build(0, 0, 0, rotation[X], rotation[Y], rotation[Z], 1, 1, 1)
	
	vbuffer_start()
	
	vertex_emissive = color_emissive
	vertex_wave = wind_wave
	if (vertex_wave != e_vertex_wave.NONE)
	{
		vertex_wave_zmin = wind_wave_zmin
		vertex_wave_zmax = wind_wave_zmax
	}
	
	// Iterate over the flat vertex list (8 reals per vertex)
	var n = ds_list_size(mesh_vertices) div 8
	for (var i = 0; i < n; i++)
	{
		var o = i * 8
		var pos = point3D(mesh_vertices[|o + 0] * scale[X], mesh_vertices[|o + 1] * scale[Y], mesh_vertices[|o + 2] * scale[Z])
		var nrm = vec3(mesh_vertices[|o + 3], mesh_vertices[|o + 4], mesh_vertices[|o + 5])
		var tex = point2D(mesh_vertices[|o + 6], mesh_vertices[|o + 7])
		
		pos = point3D_mul_matrix(pos, mat)
		nrm = vec3_mul_matrix(nrm, mat)
		
		vertex_add(pos, nrm, tex)
	}
	
	vertex_emissive = 0
	vertex_wave = e_vertex_wave.NONE
	vertex_wave_zmin = null
	vertex_wave_zmax = null
	
	return vbuffer_done()
}
