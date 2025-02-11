function ea_symmetrize_atlas(atlname)
% function to symmetrize fiber components of lead-dbs atlas dats.

if ~exist('atlname','var')
    [~,atlname]=fileparts(pwd);
end

odir=fullfile(ea_space([],'atlases'),[atlname,'_symmetrized']);
if exist(odir,'file')
    warning('Copy exists, backing up existing folder. Make sure to check nothing is overwritten.');
    movefile(odir,fullfile(ea_space([],'atlases'),[atlname,'_symmetrized_backup']));
end
copyfile(fullfile(ea_space([],'atlases'),atlname),odir);

load(fullfile(odir,'atlas_index.mat'));
ea_delete(fullfile(odir,'atlas_index.mat'));


for atlas=1:length(atlases.fv)
    if ~isempty(atlases.fv{atlas,1}) % Nifti ROI
        RH_orig = load(fullfile(odir,'rh',atlases.names{atlas}));
        LH_orig = load(fullfile(odir,'lh',atlases.names{atlas}));
        

        rfibs=RH_orig.fibers(:,1:3);
        rfibs=ea_flip_lr_nonlinear(double(rfibs));
        
        lfibs=LH_orig.fibers(:,1:3);
        lfibs=ea_flip_lr_nonlinear(double(lfibs));
       
        %write up the new 4th column of the fibers, after mirroring and
        %adding the last index for continous indexing 
        new_LH_fibers = LH_orig.fibers(:,4) + length(RH_orig.idx);
        new_RH_fibers = RH_orig.fibers(:,4) + length(LH_orig.idx);
        
        %replace the new Right side and Left side with the mirrored fibers
        RH.fibers=[RH_orig.fibers;[lfibs,new_LH_fibers]];
        LH.fibers=[LH_orig.fibers;[rfibs,new_RH_fibers]];
        
        %now perform the count for 'idx'. It will remain the same since
        %there is count of number of fibers will not change
        
        RH.idx = [RH_orig.idx;LH_orig.idx];
        LH.idx = [LH_orig.idx;RH_orig.idx];
        
%% alternate code for calculating count of fibers, maybe useful for other applications
%         uniq_new_LH_fibers = unique(new_LH_fibers);
%         numel_uniq_new_LH_fibers = numel(uniq_new_LH_fibers);
%         LH_new_indx = [];
%         for k = 1:numel_uniq_new_LH_fibers
%             LH_new_indx(k) = sum(new_LH_fibers==uniq_new_LH_fibers(k));
%         end
%         LH_new_indx = LH_new_indx';
%         uniq_new_RH_fibers = unique(new_RH_fibers);
%         numel_uniq_new_RH_fibers = numel(uniq_new_RH_fibers);
%         RH_new_indx = [];
%         for k = 1:numel_uniq_new_RH_fibers
%             RH_new_indx(k) = sum(new_RH_fibers==uniq_new_RH_fibers(k));
%         end
%         RH_new_indx = RH_new_indx';
%         
%         RH.idx=[RH_orig.idx;LH_new_indx];
%         LH.idx=[LH_orig.idx;RH_new_indx];
        
        RH.ea_fibformat = RH_orig.ea_fibformat;
        LH.ea_fibformat = LH_orig.ea_fibformat;
        
        save(fullfile(odir,'rh',atlases.names{atlas}),'-struct','RH');
        save(fullfile(odir,'lh',atlases.names{atlas}),'-struct','LH');

    end
end


% build symmetrized atlas
lead path;

options = getoptslocal;
options.atlasset = [atlname,'_symmetrized'];

ea_run('run', options);


function options = getoptslocal
options.endtolerance = 10;
options.sprungwert = 4;
options.refinesteps = 0;
options.tra_stdfactor = 0.9;
options.cor_stdfactor = 1;
options.earoot = ea_getearoot;
options.dicomimp.do = 0;
options.dicomimp.method = 1;
options.assignnii = 0;
options.normalize.do = false;
options.normalize.settings = [];
options.normalize.method = 'ea_normalize_ants';
options.normalize.methodn = 9;
options.normalize.check = false;
options.normalize.refine = 0;
options.coregmr.check = 0;
options.coregmr.method = 'SPM';
options.coregmr.do = 0;
options.overwriteapproved = 0;
options.coregct.do = false;
options.coregct.method = 'ea_coregctmri_ants';
options.coregct.methodn = 7;
options.modality = 1;
options.verbose = 3;
options.sides = [1 2];
options.doreconstruction = false;
options.maskwindow = 10;
options.automask = 1;
options.autoimprove = 0;
options.axiscontrast = 8;
options.zresolution = 10;
options.atl.genpt = false;
options.atl.normalize = 0;
options.atl.can = true;
options.atl.pt = 0;
options.atl.ptnative = false;
options.native = 0;
options.d2.col_overlay = 1;
options.d2.con_overlay = 1;
options.d2.con_color = [1 1 1];
options.d2.lab_overlay = 0;
options.d2.bbsize = 50;
options.d2.backdrop = 'MNI_ICBM_2009b_NLIN_ASYM T1';
options.d2.fid_overlay = 1;
options.d2.write = false;
options.d2.atlasopacity = 0.15;
options.d2.writeatlases = 1;
options.manualheightcorrection = false;
options.scrf.do = 0;
options.scrf.mask = 2;
options.d3.write = true;
options.d3.prolong_electrode = 2;
options.d3.verbose = 'on';
options.d3.elrendering = 1;
options.d3.exportBB = 0;
options.d3.hlactivecontacts = 0;
options.d3.showactivecontacts = 1;
options.d3.showpassivecontacts = 1;
options.d3.showisovolume = 0;
options.d3.isovscloud = 0;
options.d3.mirrorsides = 0;
options.d3.autoserver = 0;
options.d3.expdf = 0;
options.d3.writeatlases = 1;
options.numcontacts = 4;
options.entrypoint = 'STN, GPi or ViM';
options.entrypointn = 1;
options.writeoutpm = 1;
options.elmodeln = 1;
options.elmodel = 'Medtronic 3389';
options.atlassetn = 36;
options.reconmethod = 'Refined TRAC/CORE';
options.expstatvat.do = 0;
options.fiberthresh = 10;
options.writeoutstats = 1;
%%
options.colormap = [0.2422 0.1504 0.6603
                    0.250390476190476 0.164995238095238 0.707614285714286
                    0.257771428571429 0.181780952380952 0.751138095238095
                    0.264728571428571 0.197757142857143 0.795214285714286
                    0.270647619047619 0.21467619047619 0.836371428571429
                    0.275114285714286 0.234238095238095 0.870985714285714
                    0.2783 0.255871428571429 0.899071428571429
                    0.280333333333333 0.278233333333333 0.9221
                    0.281338095238095 0.300595238095238 0.941376190476191
                    0.281014285714286 0.322757142857143 0.957885714285714
                    0.279466666666667 0.344671428571429 0.971676190476191
                    0.275971428571429 0.366680952380952 0.982904761904762
                    0.269914285714286 0.3892 0.9906
                    0.260242857142857 0.412328571428571 0.995157142857143
                    0.244033333333333 0.435833333333333 0.998833333333333
                    0.220642857142857 0.460257142857143 0.997285714285714
                    0.196333333333333 0.484719047619048 0.989152380952381
                    0.183404761904762 0.507371428571429 0.979795238095238
                    0.178642857142857 0.528857142857143 0.968157142857143
                    0.176438095238095 0.549904761904762 0.952019047619048
                    0.168742857142857 0.570261904761905 0.935871428571428
                    0.154 0.5902 0.9218
                    0.146028571428571 0.609119047619048 0.907857142857143
                    0.13802380952381 0.627628571428572 0.897290476190476
                    0.124814285714286 0.645928571428571 0.888342857142857
                    0.111252380952381 0.6635 0.876314285714286
                    0.0952095238095238 0.679828571428571 0.859780952380952
                    0.0688714285714285 0.694771428571429 0.839357142857143
                    0.0296666666666667 0.708166666666667 0.816333333333333
                    0.00357142857142857 0.720266666666667 0.7917
                    0.00665714285714287 0.731214285714286 0.766014285714286
                    0.0433285714285715 0.741095238095238 0.739409523809524
                    0.096395238095238 0.75 0.712038095238095
                    0.140771428571429 0.7584 0.684157142857143
                    0.1717 0.766961904761905 0.655442857142857
                    0.193766666666667 0.775766666666667 0.6251
                    0.216085714285714 0.7843 0.5923
                    0.246957142857143 0.791795238095238 0.556742857142857
                    0.290614285714286 0.797290476190476 0.518828571428572
                    0.340642857142857 0.8008 0.478857142857143
                    0.3909 0.802871428571428 0.435447619047619
                    0.445628571428572 0.802419047619048 0.390919047619048
                    0.5044 0.7993 0.348
                    0.561561904761905 0.794233333333333 0.304480952380953
                    0.617395238095238 0.787619047619048 0.261238095238095
                    0.671985714285714 0.779271428571429 0.2227
                    0.7242 0.769842857142857 0.191028571428571
                    0.773833333333333 0.759804761904762 0.164609523809524
                    0.820314285714286 0.749814285714286 0.153528571428571
                    0.863433333333333 0.7406 0.159633333333333
                    0.903542857142857 0.733028571428571 0.177414285714286
                    0.939257142857143 0.728785714285714 0.209957142857143
                    0.972757142857143 0.729771428571429 0.239442857142857
                    0.995647619047619 0.743371428571429 0.237147619047619
                    0.996985714285714 0.765857142857143 0.219942857142857
                    0.995204761904762 0.789252380952381 0.202761904761905
                    0.9892 0.813566666666667 0.188533333333333
                    0.978628571428571 0.838628571428572 0.176557142857143
                    0.967647619047619 0.8639 0.164290476190476
                    0.961009523809524 0.889019047619048 0.153676190476191
                    0.959671428571429 0.913457142857143 0.142257142857143
                    0.962795238095238 0.937338095238095 0.126509523809524
                    0.969114285714286 0.960628571428571 0.106361904761905
                    0.9769 0.9839 0.0805];
%%
options.dolc = 0;
options.ecog.extractsurface.do = 0;
options.ecog.extractsurface.method = 1;
options.uipatdirs = [];
options.leadprod = 'dbs';

options.prefs=ea_prefs;

options.lc.general.parcellation = '';
options.lc.graph.struc_func_sim = 0;
options.lc.graph.nodal_efficiency = 0;
options.lc.graph.eigenvector_centrality = 0;
options.lc.graph.degree_centrality = 1;
options.lc.graph.fthresh = NaN;
options.lc.graph.sthresh = NaN;
options.lc.func.compute_CM = 0;
options.lc.func.compute_GM = 0;
options.lc.func.prefs.TR = 2.69;
options.lc.struc.compute_CM = 0;
options.lc.struc.compute_GM = 0;
options.lc.struc.ft.method = 'ea_ft_gqi_yeh';
options.lc.struc.ft.do = 1;
options.lc.struc.ft.normalize = 0;
options.lc.struc.ft.dsistudio.fiber_count = 200000;
options.lc.struc.ft.upsample.factor = 1;
options.lc.struc.ft.upsample.how = 0;
options.exportedJob = 1;

