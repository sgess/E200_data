function data=add_step_info(data,step_name,step_value)
	UID=data.raw.scalars.step_num.UID;
    PID=data.raw.scalars.step_num.PID;
	size_UID = size(UID,2);
	data.raw.scalars.step_name=add_raw(cell_construct(step_name,1,size_UID),UID,PID,'EPICS');
	data.raw.scalars.step_value=add_raw(step_value*ones(1,size_UID),UID,PID,'EPICS');
end
