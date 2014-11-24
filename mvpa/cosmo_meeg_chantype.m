function [chantypes,senstype_mapping]=cosmo_meeg_chantype(ds,varargin)
% return channel types and optionally a feature mask matching a type
%
% [chantypes,senstype_mapping]=cosmo_meeg_chantype(ds)
%
% Inputs:
%    ds                 dataset struct for MEEG dataset
%
% Output:
%    chantypes          1xN cell with type of each channel in ds, where
%                       N is the number of channels.
%    senstype_mapping   struct with keys the unique chantypes, and values
%                       the sensor (acquisition) type
%
% Example:
%     % generate synthetic dataset with meg_planar and meg_axial channels
%     % as found in the neuromag306 system
%     ds=cosmo_synthetic_dataset('type','meeg','sens','neuromag306_all',...
%                     'size','big','nchunks',1,'ntargets',1);
%     [chantypes,senstypes]=cosmo_meeg_chantype(ds);
%     cosmo_disp(chantypes);
%     > { 'meg_axial'
%     >   'meg_planar'
%     >   'meg_planar'
%     >        :
%     >   'meg_axial'
%     >   'meg_planar'
%     >   'meg_planar' }@306x1
%     disp(senstypes)
%     >      meg_axial: 'neuromag306alt_mag'
%     >     meg_planar: 'neuromag306alt_planar'
%     %
%     % filter the dataset to only contain the planar channels:
%     %
%     % see which features have a matching channel
%     chan_indices=find(cosmo_match(chantypes,'meg_planar'));
%     planar_msk=cosmo_match(ds.fa.chan,chan_indices);
%     % slice and prune dataset along feature dimension
%     ds_planar=cosmo_dim_slice(ds,planar_msk,2);
%     % the output dataset has only the 204 planar channels left
%     cosmo_disp(ds_planar.a.fdim);
%     > .labels
%     >   { 'chan'  'time' }
%     > .values
%     >   { { 'MEG0112'          [  -0.2
%     >       'MEG0113'            -0.15
%     >       'MEG0212'             -0.1
%     >          :                   :
%     >       'MEG2543'                0
%     >       'MEG2642'             0.05
%     >       'MEG2643' }@204x1      0.1 ]@7x1 }
%     %
%     cosmo_disp(ds_planar.fa.chan);
%     > [ 1         2         3  ...  202       203       204 ]@1x1428
%
% NNO Nov 2014

    defaults=struct();
    % quality scores of match between labels and senstype
    defaults.label_threshold=.25;
    defaults.layout_threshold=.3;
    defaults.both_threshold=.4;
    opt=cosmo_structjoin(defaults,varargin);


    labels=get_channel_labels(ds);
    nlabels=numel(labels);

    senstype_collection=cosmo_meeg_senstype_collection();
    keys=fieldnames(senstype_collection);
    nkeys=numel(keys);

    % get channel types and labels for each sensor type
    all_chantypes=cell(nkeys,1);
    all_senstypes=cell(nkeys,1);
    all_sens_labels=cell(nkeys,1);
    for k=1:nkeys
        key=keys{k};
        senstype=senstype_collection.(key);
        all_senstypes{k}=senstype.sens;
        all_sens_labels{k}=senstype.label(:);
        all_chantypes{k}=senstype.type;
    end

    % compute quality for each sensor type
    all_quality=compute_overlap(labels, all_sens_labels);

    % restrict to the best one in each modality
    [keep_idxs,quality]=get_best_idxs(all_quality,opt);
    keep_types=all_chantypes(keep_idxs);
    keep_quality=quality(keep_idxs);

    if isempty(keep_quality)
        error('Could not identify channel type');
    end

    % set the channel types
    [idxs,unq_types_cell]=cosmo_index_unique({keep_types});
    sens_chantypes=unq_types_cell{1};
    nsenstypes=numel(idxs);

    visited_msk=false(nlabels,1);
    chantypes=cell(nlabels,1);
    senstype_mapping=struct();

    for k=1:nsenstypes;
        idx=idxs{k};
        [unused,i]=max(keep_quality(idx));
        all_idx=keep_idxs(idx(i));

        hit_msk=cosmo_match(labels,all_sens_labels{all_idx});
        chantypes(hit_msk)=sens_chantypes(k);
        visited_msk=visited_msk|hit_msk;

        senstype_mapping.(sens_chantypes{k})=keys{all_idx};
    end

    chantypes(~visited_msk)={'unknown'};

function [keep_idxs,quality]=get_best_idxs(all_quality, opt)

    qs=[all_quality, mean(all_quality,2)];
    thrs=[opt.label_threshold, opt.layout_threshold opt.both_threshold];

    for j=1:3
        quality=qs(:,j);
        keep_idxs=find(quality>thrs(j));
        if ~isempty(keep_idxs)
            return
        end
    end

    error('Could not identify channel type');


function quality=compute_overlap(x,ys)
    % x is a cellstring
    % y is a cell with cellstrings

    nx=numel(x);
    ny=numel(ys);
    nys=zeros(ny,1);

    ntotal_cell=cell(ny+1,1);
    strs_cell=cell(ny+1,1);

    ntotal_cell{1}=ones(nx,1);
    strs_cell{1}=x;
    for k=1:ny
        nys(k)=numel(ys{k});
        ntotal_cell{k+1}=ones(nys(k),1)*(k+1);
        strs_cell{k+1}=ys{k};
    end
    idxs=cat(1,ntotal_cell{:});
    strs=cat(1,strs_cell{:});

    [ii,unq_cell]=cosmo_index_unique({strs});
    unq=unq_cell{1};

    nunq=numel(unq);
    h=zeros(ny,1);
    for k=1:nunq
        vs=idxs(ii{k});
        if vs(1)==1
            h(vs(2:end)-1)=h(vs(2:end)-1)+1;
        end
    end

    quality=[h./nx,h./nys];


function chan_labels=get_channel_labels(ds)
    if iscellstr(ds)
        chan_labels=ds;
    else
        [dim, index, attr_name, dim_name]=cosmo_dim_find(ds,'chan',true);
        chan_labels=ds.a.(dim_name).values{index};
    end



