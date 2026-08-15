/// model_shape_event_destroy()

function model_shape_event_destroy()
{
	if (vbuffer_default != null)
		vbuffer_destroy(vbuffer_default)
	
	// PLUS-FORK: free mesh vertex data
	if (mesh_vertices != null)
		ds_list_destroy(mesh_vertices)
}
