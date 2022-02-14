function ea_coregmr(options)
% wrapper for coregister post-op MR to pre-op MR

% in CT imaging, coregistration is done elsewhere.
% also ignore when there is no tra/cor/sag existing (normal conn study)
if options.modality == 2 || ~isfield(options.prefs,'tranii_unnormalized')
    return
end

directory=[options.root,options.patientname,filesep];

doreslice=1;

% restore raw files -> postop files from prior attempts. & make backups
% from original files in any case.
try
    if  ~ea_coreglocked(options,[directory,options.prefs.tranii_unnormalized]) % file has already been locked and approved by used
        ea_backuprestore([directory,options.prefs.tranii_unnormalized]);
    end
end

try
    if  ~ea_coreglocked(options,[directory,options.prefs.cornii_unnormalized]) % file has already been locked and approved by used
        ea_backuprestore([directory,options.prefs.cornii_unnormalized]);
    end
end

try
    if  ~ea_coreglocked(options,[directory,options.prefs.sagnii_unnormalized]) % file has already been locked and approved by used
        ea_backuprestore([directory,options.prefs.sagnii_unnormalized]);
    end
end

switch options.coregmr.method
    case 'SPM' % SPM
        ea_coregmr_spm(options,doreslice);
    case 'FSL FLIRT' % FSL FLIRT
        ea_coregmr_flirt(options);
    case 'FSL BBR' % FSL FLIRT
        ea_coregmr_flirt_bbr(options);
    case 'ANTs' % ANTs
        ea_coregmr_ants(options,0);
    case 'BRAINSFIT' % BRAINSFit
        ea_coregmr_brainsfit(options);
    case 'Hybrid SPM & ANTs' % Hybrid SPM -> ANTs
        ea_coregmr_spm(options,0); % dont use doreslice here to refrain for doing two interpolations.
        ea_coregmr_ants(options);
    case 'Hybrid SPM & BRAINSFIT' % Hybrid SPM -> Brainsfit
        ea_coregmr_spm(options,0); % dont use doreslice here to refrain for doing two interpolations.
        ea_coregmr_brainsfit(options);
    case 'ANTs Nonlinear Coregistration'
        warning('off', 'backtrace');
        warning('ANTs nonlinear coregistration only supports pre-op to pre-op registration, falling back to linear coregistration now!')
        warning('on', 'backtrace');
        ea_coregmr_ants(options,0);
end

ea_dumpnormmethod(options,options.coregmr.method,'coregmrmethod');
