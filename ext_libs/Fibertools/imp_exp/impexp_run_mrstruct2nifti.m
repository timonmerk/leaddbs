function varargout = impexp_run_mrstruct2nifti(cmd, varargin)
% Template function to implement callbacks for an cfg_exbranch. The calling
% syntax is
% varargout = impexp_run_mrstruct2nifti(cmd, varargin)
% where cmd is one of
% 'run'      - out = impexp_run_mrstruct2nifti('run', job)
%              Run a job, and return its output argument
% 'vout'     - dep = impexp_run_mrstruct2nifti('vout', job)
%              Examine a job structure with all leafs present and return an
%              array of cfg_dep objects.
% 'check'    - str = impexp_run_mrstruct2nifti('check', subcmd, subjob)
%              Examine a part of a fully filled job structure. Return an empty
%              string if everything is ok, or a string describing the check
%              error. subcmd should be a string that identifies the part of
%              the configuration to be checked.
% 'defaults' - defval = impexp_run_mrstruct2nifti('defaults', key)
%              Retrieve defaults value. key must be a sequence of dot
%              delimited field names into the internal def struct which is
%              kept in function local_def. An error is returned if no
%              matching field is found.
%              impexp_run_mrstruct2nifti('defaults', key, newval)
%              Set the specified field in the internal def struct to a new
%              value.
% Application specific code needs to be inserted at the following places:
% 'run'      - main switch statement: code to compute the results, based on
%              a filled job
% 'vout'     - main switch statement: code to compute cfg_dep array, based
%              on a job structure that has all leafs, but not necessarily
%              any values filled in
% 'check'    - create and populate switch subcmd switchyard
% 'defaults' - modify initialisation of defaults in subfunction local_defs
% Callbacks can be constructed using anonymous function handles like this:
% 'run'      - @(job)impexp_run_mrstruct2nifti('run', job)
% 'vout'     - @(job)impexp_run_mrstruct2nifti('vout', job)
% 'check'    - @(job)impexp_run_mrstruct2nifti('check', 'subcmd', job)
% 'defaults' - @(val)impexp_run_mrstruct2nifti('defaults', 'defstr', val{:})
%              Note the list expansion val{:} - this is used to emulate a
%              varargin call in this function handle.
%
% This code is part of a batch job configuration system for MATLAB. See 
%      help matlabbatch
% for a general overview.
%_______________________________________________________________________
% Copyright (C) 2007 Freiburg Brain Imaging

% Volkmar Glauche
% $Id: impexp_run_mrstruct2nifti.m,v 1.2 2010/07/01 09:28:16 glauche Exp $

rev = '$Rev: 315 $'; %#ok

if ischar(cmd)
    switch lower(cmd)
        case 'run'
            job = local_getjob(varargin{1});
            % do computation, return results in variable out
            if isfield(job.output.outname,'outimg')
                outdir = job.output.outname.outimg.outdir;
                outname = {job.output.outname.outimg.fname};
            else
                outdir = {pwd};
                outname = {'mrstruct.nii'};
            end
            if isfield(job.srcchoice,'srcvar')
                mrStruct=job.srcchoice.srcvar;
            else
                % postpone read
                mrStruct = job.srcchoice.srcstruct;
                if isfield(job.output.outname,'autoimg')
                    for k = 1:numel(job.srcchoice.srcstruct)
                        [outdir{k} n] = fileparts(job.srcchoice.srcstruct{k});
                        outname{k}    = sprintf('%s.nii',n);
                    end
                end
            end
            if numel(outname) ~= numel(mrStruct)
                nmrs = ceil(log10(numel(mrStruct)));
                [p n e] = fileparts(outname{1});
                on = sprintf('%s%%.0%dd%s',n,nmrs,e);
                for k = 1:numel(mrStruct)
                    outdir{k} = outdir{1};
                    outname{k} = sprintf(on, k);
                end
            end
            out.files = {};
            for k = 1:numel(mrStruct)
                if isstruct(mrStruct)
                    cmrStruct = mrStruct(k);
                elseif iscellstr(mrStruct)
                    cmrStruct = mrstruct_read(mrStruct{k});
                else
                    cmrStruct = mrStruct{k};
                end
                [Vo errstr]=mrstruct_to_nifti(cmrStruct, fullfile(outdir{1}, ...
                                                                  outname{k}), spm_type(job.output.dtype));
                if ~isempty(errstr)
                    error(errstr);
                end;
                Vo = cell2mat(Vo);
                files1 = cellstr(char(Vo.fname));
                out.files = [out.files(:); files1(:)];
            end
            if nargout > 0
                varargout{1} = out;
            end
        case 'vout'
            job = local_getjob(varargin{1});
            % initialise empty cfg_dep array
            dep = cfg_dep;
            % determine outputs, return cfg_dep array in variable dep
            dep(1).sname = 'Output file(s)';
            dep.src_output = substruct('.','files');
            dep.tgt_spec   = cfg_findspec({{'filter','image','strtype','e'}});
            varargout{1} = dep;
        case 'check'
            if ischar(varargin{1})
                subcmd = lower(varargin{1});
                subjob = varargin{2};
                str = '';
                switch subcmd
                    case 'ismrstruct'
                        % implement checks, return status string in variable str
                        if mrstruct_istype(subjob)
                            str = '';
                        else
                            str = 'Input is not a mrStruct variable.';
                        end
                    otherwise
                        cfg_message('unknown:check', ...
                            'Unknown check subcmd ''%s''.', subcmd);
                end
                varargout{1} = str;
            else
                cfg_message('ischar:check', 'Subcmd must be a string.');
            end
        case 'defaults'
            if nargin == 2
                varargout{1} = local_defs(varargin{1});
            else
                local_defs(varargin{1:2});
            end
        otherwise
            cfg_message('unknown:cmd', 'Unknown command ''%s''.', cmd);
    end
else
    cfg_message('ischar:cmd', 'Cmd must be a string.');
end

function varargout = local_defs(defstr, defval)
persistent defs;
if isempty(defs)
    % initialise defaults
end
if ischar(defstr)
    % construct subscript reference struct from dot delimited tag string
    tags = textscan(defstr,'%s', 'delimiter','.');
    subs = struct('type','.','subs',tags{1}');
    try
        cdefval = subsref(local_def, subs);
    catch
        cdefval = [];
        cfg_message('defaults:noval', ...
            'No matching defaults value ''%s'' found.', defstr);
    end
    if nargin == 1
        varargout{1} = cdefval;
    else
        defs = subsasgn(defs, subs, defval);
    end
else
    cfg_message('ischar:defstr', 'Defaults key must be a string.');
end

function job = local_getjob(job)
if ~isstruct(job)
    cfg_message('isstruct:job', 'Job must be a struct.');
end