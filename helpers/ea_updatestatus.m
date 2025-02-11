function ea_updatestatus(handles)

uipatdir=getappdata(handles.leadfigure,'uipatdir');

statusone = 'One or more MR-/CT-volumes missing.';
set(handles.statusone,'String',statusone);
set(handles.statusone,'TooltipString',statusone);

modality=ea_checkctmrpresent(handles);

% check if MRCT popup is set correctly
if any(modality)
   if ~modality(get(handles.MRCT,'Value'))
       set(handles.MRCT,'ForegroundColor',[0.8,0.5,0.5]);
   else
       set(handles.MRCT,'ForegroundColor',[0.5,0.8,0.5]);
   end

end

% check for reconstructions
if exist([uipatdir{1},filesep,'ea_coords.fcsv'],'file') && exist([uipatdir{1},filesep,'ea_reconstruction.mat'],'file')
    statustwo = 'Fiducials and Trajectory information present in folder. Will be overwritten if "Reconstruct" is set.';
elseif exist([uipatdir{1},filesep,'ea_coords.fcsv'],'file') && ~exist([uipatdir{1},filesep,'ea_reconstruction.mat'],'file')
    statustwo = 'Fiducials information present in folder. Will be overwritten if "Reconstruct" is set.';
elseif ~exist([uipatdir{1},filesep,'ea_coords.fcsv'],'file') && exist([uipatdir{1},filesep,'ea_reconstruction.mat'],'file')
    statustwo = 'Trajectory information present in folder. Will be overwritten if "Reconstruct" is set.';
elseif ~exist([uipatdir{1},filesep,'ea_coords.fcsv'],'file') && ~exist([uipatdir{1},filesep,'ea_reconstruction.mat'],'file')
    statustwo = 'No reconstruction available in folder. Set "Reconstruct" to start.';
end

set(handles.statustwo,'String',statustwo);
set(handles.statustwo,'TooltipString',statustwo);
