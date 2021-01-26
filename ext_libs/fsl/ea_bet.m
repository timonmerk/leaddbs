function ea_bet(inputimage, outputmask, outputimage, fraintthreshold)
% Wrapper for bet2 or SPM based brain extraction

% Do not output brain mask by default
if nargin < 2
    outputmask = 0;
end

% overwrite the input image
if ~exist('outputimage','var')
    outputimage = inputimage;
else
    if isempty(outputimage)
        outputimage=inputimage;
    end
end

% If no threshold is set, the default fractional intensity threshold (0->1) is set
% to default=0.5 (as set in FSL binary), smaller values give larger brain outline estimates
if nargin < 4
    fraintthreshold = 0.5;
else
    if ischar(fraintthreshold)
        switch lower(fraintthreshold)
            case {'usespm','spm'}
                ea_brainextract_spm(inputimage, outputmask, outputimage)
                return
        end
    end
end

fprintf('\n\nRunning FSL BET2: %s\n\n', inputimage);

inputimage = ea_path_helper(ea_niigz(inputimage));
outputimage = ea_path_helper(ea_niigz(outputimage));

% Remove the '.nii' or '.nii.gz' ext
outputimage = ea_niifileparts(outputimage);

basedir = [fileparts(mfilename('fullpath')), filesep];
if ispc
    BET = ea_path_helper([basedir, 'bet2.exe']);
else
    BET = [basedir, 'bet2.', computer('arch')];
end

cmd = [BET, ...
       ' ', inputimage, ...
       ' ', outputimage, ...
       ' --verbose'];

if outputmask
    cmd = [cmd, ' -m'];
end

cmd = [cmd, ' -f ' ,num2str(fraintthreshold)];

setenv('FSLOUTPUTTYPE','NIFTI');
if ~ispc
    system(['bash -c "', cmd, '"']);
else
    system(cmd);
end

fprintf('\nFSL BET2 finished\n');



function ea_brainextract_spm(inputimage, outputmask, outputimage)

[inpth,infn,inext]=fileparts(inputimage);

copyfile(fullfile(inpth,[infn,inext]),fullfile(ea_getleadtempdir,[infn,inext]));
if strcmp(inext,'.gz')
    gunzip(fullfile(ea_getleadtempdir,[infn,inext]))
    wasgz=1;
    delete(fullfile(ea_getleadtempdir,[infn,inext]));
    tempfile=fullfile(ea_getleadtempdir,[infn]);
else
    wasgz=0;
    tempfile=fullfile(ea_getleadtempdir,[infn,inext]);
end

[pth,fn,ext]=fileparts(tempfile);
options.prefs=ea_prefs;
ea_newseg([pth,filesep],[fn,ext],0,options,0,1)
AllX=[];
for c=1:3
   mask=ea_load_nii(fullfile(pth,['c',num2str(c),fn,ext]));
   AllX=[AllX,mask.img(:)];
   ea_delete(fullfile(pth,['c',num2str(c),fn,ext]));
end
ea_delete(fullfile(pth,['iy_',fn,ext]));
ea_delete(fullfile(pth,['y_',fn,ext]));
AllX=sum(AllX,2);
mask.img(:)=AllX;
mask.img=mask.img>0.2;
mask.fname=fullfile(pth,[fn,'_mask',ext]);
if outputmask
   ea_write_nii(mask); 
end
input=ea_load_nii([tempfile,',1']);
input.img=input.img.*(mask.img);
input.fname=fullfile(pth,[fn,'_brain',ext]);
ea_write_nii(input);

% move result to output:
[opth,ofn,oext]=fileparts(outputimage);
if strcmp(ext,'.gz')
    gzip(fullfile(pth,[fn,'_brain',ext]));
    ea_delete(fullfile(pth,[fn,'_brain',ext]));
    movefile(fullfile(pth,[fn,'_brain',ext,'.gz']),outputimage);
else
    movefile(fullfile(pth,[fn,'_brain',ext]),outputimage);
end

if outputmask
    if wasgz
       gzip(fullfile(pth,[fn,'_mask',ext]));
       ea_delete(fullfile(pth,[fn,'_mask',ext]));
       movefile(fullfile(pth,[fn,'_mask',ext,'.gz']),fullfile(inpth,[fn,'_mask',ext,'.gz']));
    else
        movefile(fullfile(pth,[fn,'_mask',ext]),fullfile(inpth,[fn,'_mask',ext]));
    end
end


