function data=E200_gather_data(path,varargin)
	if nargin>1
		scan_step=varargin{1};
	else
		scan_step=1;
	end
	% Initialize data structure
	data             = struct();
	data.Version = 0.1;

	data.raw         = struct();
	data.raw.images  = struct();
	data.raw.scalars = struct();
	data.raw.vectors = struct();
	data.raw.arrays  = struct();

	data.processed   = data.raw;

	data.user=struct();

	% Get path and filename
	% path='/nas/nas-li20-pm01/E200/2013/20130511/E200_11071/E200_11071_scan_info.mat';
	% path='/nas/nas-li20-pm01/E200/2013/20130520/E200_11208/E200_11208_2013-05-20-19-04-30_filenames.mat';
	path='/nas/nas-li20-pm01/E200/2013/20130520/E200_11209/E200_11209_2013-05-20-22-32-18_filenames.mat';
	[Pathname,name,extension,versn]=fileparts(path);
	Filename=[name extension versn];

	% Save some info for development purposes
	data.user.dev.path=path;
	data.user.dev.Pathname=Pathname;
	data.user.dev.Filename=Filename;
	
	% Determine which file type is being used.
	settype='none';
	searchlist = {{'scan_info.mat','scan'},{'filenames.mat','daq'}};
	% searchlist = {{'scan_info.mat','scan'}};
	if (Filename~=0)
		for searchstr=searchlist
			if ~isempty(strfind(Filename,searchstr{1}{1}))
				settype=searchstr{1}{2};
	        	end
		end
	else
	    error('File not valid.');
	end
	
	% Type-specific Initialization\
	switch settype
	    case 'scan'
	
	        % Load scan_info file
	        load(path);
	        
	        % Load first filename file
	        dirs=dir(fullfile(Pathname,'*_2013*.mat'));
	        load(fullfile(Pathname,dirs(1).name));

		data.user.dev.load=fullfile(Pathname,dirs(1).name);
		
		% Initialize data.raw.images
		

	        n_steps=size(scan_info,2);
	
		% handles.scan.scan_info=scan_info;
		% handles.scan.n_steps=n_steps;
	        
	    case 'daq'
	        % Load file
	        load(fullfile(Pathname,[Filename(1:end-14) '.mat']));
	        load(path);

		% Convert epics_data to a list
		n_e_shots      = size(epics_data,2);
		epics_data_mat = cell2mat(squeeze(struct2cell(epics_data)));

		% Generate epics-type UID
		bool        = strcmp('PATT_SYS1_1_PULSEID',fieldnames(epics_data));
		e_PID       = epics_data_mat(bool,:);
		e_scan_step = ones(1,n_e_shots)*scan_step;
		dataset     = str2num(param.save_name(6:10));
		e_dataset   = dataset * ones(1,n_e_shots);
		UIDs        = assign_UID(e_PID,e_scan_step,e_dataset);
		e_UID       = UIDs.epics_UID;

		% Put in epics_data
		names=fieldnames(epics_data);
		for i=1:size(names,1)
			data.raw.scalars.(names{i})=add_raw(epics_data_mat(i,:),e_UID,'EPICS');
		end

		% Save these things to the struct
		data.raw.scalars.step           = add_raw(e_scan_step,e_UID,'EPICS');
		data.raw.scalars.dataset_number = add_raw(e_dataset, e_UID, 'EPICS');

		% Extract and save backgrounds (consistency)
		% First check and make directories
		imgpath=fullfile(Pathname,'images');
		if ~( exist( imgpath )==7 )
			mkdir(imgpath);
		end
		% Save backgrounds to file
		camstr=fieldnames(cam_back);
		for i=1:size(camstr,1)
			% bgname=[camstr{i} '_set' num2str(dataset) '_step' num2str(scan_step) '.mat'];
			bg_name=bgname(camstr{i},dataset,scan_step);
			bgpath=fullfile(imgpath,bg_name);
			% Save if backgrounds don't exist
			if ~( exist(bgpath)==2 )
				display('Saving background file...');
				img=cam_back.(camstr{i}).img;
				cam_back.(camstr{i})=rmfield(cam_back.(camstr{i}),'img');
				save(bgpath,'img');
			end
		end

		% Initialize data.raw.images.(name)
		format=cell_construct('bin',1,n_e_shots);
		for i=1:size(param.cams,1)
			str=param.cams{i,1};
			data.raw.images.(str)=struct();
			data.raw.images.(str)=replace_field(data.raw.images.(str),...
							'dat'			, cell_construct(filenames.(str),1,n_e_shots),...
							'format'		, format, ...
							'bin_index'		, [1:n_e_shots], ...
							'background_dat'	, bgname(str,dataset,scan_step),...
							'background_format'	, 'mat', ...
							'IDtype'		, 'Image');
			% Add the remaining info from cam_back
			names=fieldnames(cam_back.(str));
			for i=1:size(names,1)
				data.raw.images.(str).(names{i})=cam_back.(str).(names{i});
			end
		end


		% Add metadata
		data.raw.metadata.param=add_raw(cell_construct(param,1,n_e_shots), e_UID,'EPICS');
	        
	    case 'none'
		    error('Filetype not understood.');
	end
	
	% All file initializations
	if ~strcmp(settype,'none')
	end
end

function out=add_raw(dat,UID,IDtype)
	valid_IDtypes = {'EPICS','AIDA','Image'};
	if sum(strcmp(IDtype,valid_IDtypes))<1
		error('Use a valid IDtype.');
	end
	if iscell(dat)
		out=struct();
		out=replace_field(out,'dat',dat,'UID',UID,'IDtype',IDtype);
	else
		out=struct('dat',dat,'UID',UID,'IDtype',IDtype);
	end
end

function out=bgname(str,set,step)
	out=['Background_' str '_set' num2str(set) '_step' num2str(step) '.mat'];
end
