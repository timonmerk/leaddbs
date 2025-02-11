function [vals] = ea_networkmapping_calcstats(obj,patsel,Iperm)

if ~exist('Iperm','var')
    I=obj.responsevar;
else % used in permutation based statistics - in this case the real improvement can be substituted with permuted variables.
    I=Iperm;
end

AllX = (obj.results.(ea_conn2connid(obj.connectome)).connval);

% quickly recalc stats:
if ~exist('patsel','var') % patsel can be supplied directly (in this case, obj.patientselection is ignored), e.g. for cross-validations.
    patsel=obj.patientselection;
end

if size(I,2)==2 % 1 entry per patient, not per electrode
    I=mean(I,2); % both sides the same;
end

if obj.mirrorsides
    I=[I;I];
end

if ~isempty(obj.covars)
    for i=1:length(obj.covars)
        if obj.mirrorsides
            covars{i} = [obj.covars{i};obj.covars{i}];
        else
            covars{i} = obj.covars{i};
        end
    end
end

if exist('covars', 'var')
   I = ea_resid(cell2mat(covars),I);
end

if obj.splitbygroup
    groups=unique(obj.M.patient.group)';
    dogroups=1;
else
    groups=1; % all one, group ignored
    dogroups=0;
end

for group=groups
    if dogroups
        groupspt=find(obj.M.patient.group==group);
        gpatsel=groupspt(ismember(groupspt,patsel));
    else
        gpatsel=patsel;
    end

    if obj.mirrorsides
        gpatsel=[gpatsel,gpatsel+length(obj.allpatients)];
    end

    switch obj.statmetric
        case 'Correlations (R-map)'
            disp(['Correlation type: ', obj.corrtype, '. Calculating R-map...'])
            % no covariates exist:
            if obj.showsignificantonly
                [vals{group},ps]=ea_corr(I(gpatsel),(AllX(gpatsel,:)),obj.corrtype);
                vals{group}=ea_corrsignan(vals{group},ps',obj);
            else
                [vals{group}]=ea_corr(I(gpatsel),(AllX(gpatsel,:)),obj.corrtype); % improvement values (taken from Lead group file or specified in line 12).
            end
        case 'Weighted Average (A-map)' % check
            disp('Calculating A-map...')
            % no covariates exist:
            [vals{group}]=ea_nansum(AllX(gpatsel,:).*repmat(I(gpatsel),1,size(AllX(gpatsel,:),2)),1);
        case 'Combined (C-map)'
            disp(['Correlation type: ', obj.corrtype, '. Calculating C-map...'])
            if obj.showsignificantonly
                [R,ps]=ea_corr(I(gpatsel),(AllX(gpatsel,:)),obj.corrtype); % improvement values (taken from Lead group file or specified in line 12).
                R=ea_corrsignan(vals{group},ps',obj);
                A=ea_nansum(AllX(gpatsel,:).*repmat(I(gpatsel),1,size(AllX(gpatsel,:),2)),1);
                bidir=(R.*A)>0; % check for entries that are either positive or negative in both maps
                A(~bidir)=nan;
                vals{group}=A;
            else
                R=ea_corr(I(gpatsel),(AllX(gpatsel,:)),obj.corrtype); % improvement values (taken from Lead group file or specified in line 12).
                A=ea_nansum(AllX(gpatsel,:).*repmat(I(gpatsel),1,size(AllX(gpatsel,:),2)),1);
                bidir=(R.*A)>0; % check for entries that are either positive or negative in both maps
                A(~bidir)=nan;
                vals{group}=A;
            end
    end

    obj.stats.pos.available=sum(vals{1}>0); % only collected for first group (positives)
    obj.stats.neg.available=sum(vals{1}<0);
end


function vals=ea_corrsignan(vals,ps,obj)

nnanidx=~isnan(vals);
numtests=sum(nnanidx);

switch lower(obj.multcompstrategy)
    case 'fdr'
        pnnan=ps(nnanidx);
        [psort,idx]=sort(pnnan);
        pranks=zeros(length(psort),1);
        for rank=1:length(pranks)
           pranks(idx(rank))=rank;
        end
        pnnan=pnnan.*numtests;
        pnnan=pnnan./pranks;
        ps(nnanidx)=pnnan;
    case 'bonferroni'
        ps(nnanidx)=ps(nnanidx).*numtests;
end
ps(~nnanidx)=1;
vals(ps>obj.alphalevel)=nan; % delete everything nonsignificant.
