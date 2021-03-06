function test_suite = test_fmri_orientations
    initTestSuite;


function test_orientations()
    % make dataset
    ds=cosmo_synthetic_dataset('size','big');
    ds=cosmo_slice(ds,1);
    ds.a.vol.mat(1:3,4)=ds.a.vol.mat(1:3,4)-20;

    orig_orient=cosmo_fmri_orientation(ds);
    assertEqual(orig_orient,'LPI');

    % get all orientations and
    orients=get_orients();
    norient=numel(orients);

    fmts={'.nii','.nii.gz','+orig.HEAD','+tlrc.HEAD'};
    nfmt=numel(fmts);

    nperm=nfmt*norient;

    ntest=5;
    rp=randperm(nperm);
    ncoord=10;
    for k=1:ntest
        p=rp(k);
        orient_idx=ceil(p/nfmt);
        fmt_idx=mod(k-1,nfmt)+1;

        orient=orients{orient_idx};
        fmt=fmts{fmt_idx};

        ijk=ceil(bsxfun(@times,rand(4,ncoord),[ds.a.vol.dim(:);1]));
        orient_idx=get_feature_index(ds,ijk);
        xyz=ds.a.vol.mat*ijk;

        % verify equality with re-orirented dataset
        ds_ro=cosmo_fmri_reorient(ds,orient);  % using CoSMoMVPA
        assertEqual(cosmo_fmri_orientation(ds_ro),orient);

        ijk_ro=ds_ro.a.vol.mat\xyz;
        idx_ro=get_feature_index(ds_ro,ijk_ro);
        assertElementsAlmostEqual(ds.samples(:,orient_idx),...
                                  ds_ro.samples(:,idx_ro),...
                                  'absolute',1e-5);


        % verify that going back works fine
        ds2=cosmo_fmri_reorient(ds_ro,orig_orient);
        assertEqual(ds,ds2);
    end

function test_fmri_orientations_with_afni_binary()
    has_afni=cosmo_check_external('afni_bin',false);
    if ~has_afni
        cosmo_notify_test_skipped('afni binaries not available');
        return
    end

    ds=cosmo_synthetic_dataset('size','big');
    fmt='.nii';
    orients=get_orients();
    i=ceil(rand()*numel(orients));
    orient=orients{i};

    ds_rs=afni_resample(ds,fmt,orient); % in AFNI
    assertEqual(cosmo_fmri_orientation(ds_rs),orient);

    % verify equality with resampled dataset
    ijk_rs=ds_rs.a.vol.mat\xyz;
    idx_rs=get_feature_index(ds_rs,ijk_rs);
    assertElementsAlmostEqual(ds.samples(:,orient_idx),...
                              ds_rs.samples(:,idx_rs),...
                              'absolute',1e-5);


function idxs=get_feature_index(ds, ijk)
    n=size(ijk,2);
    idxs=zeros(1,n);

    i=ds.fa.i;
    j=ds.fa.j;
    k=ds.fa.k;

    for m=1:n
        msk=i==ijk(1,m) & j==ijk(2,m) & k==ijk(3,m);
        idx=find(msk);
        assert(numel(idx)==1);
        idxs(m)=idx;
    end


function orients=get_orients()
    % get all 48 possible orientations
    order=perms(1:3);
    signs=[1 0 1 0 1 0 1 0;
           1 1 0 0 1 1 0 0;
           1 1 1 1 0 0 0 0];

    labs=['LR';'PA';'IS'];

    orients=cell(48,1);

    for k=1:6
        for j=1:8
            orient='   ';
            for dim=1:3
                row=order(k,dim);
                orient(dim)=(labs(row,signs(row,j)+1));
            end
            orients{(k-1)*8+j}=orient;
        end
    end

function [success,output]=run_afni_command(cmd,raise)
    if nargin<2
        raise=false;
    end
    dyld_path=getenv('DYLD_LIBRARY_PATH');
    cleaner=onCleanup(@()setenv('DYLD_LIBRARY_PATH',dyld_path));
    setenv('DYLD_LIBRARY_PATH','/usr/local/bin');

    dyld_fb_path=getenv('DYLD_FALLBACK_LIBRARY_PATH');
    cleaner2=onCleanup(@()setenv('DYLD_FALLBACK_LIBRARY_PATH',...
                                        dyld_fb_path));
    setenv('DYLD_FALLBACK_LIBRARY_PATH',...
                [getenv('DYLD_FALLBACK_LIBRARY_PATH') ':/sw/lib']);

    [s,output]=unix(cmd);
    success=s==0;

    if ~success && raise
        error(output);
    end




function ds_rs=afni_resample(ds,fmt,orient)
    tmp_pat=['tmp_%d' fmt];
    [fn_orig,cleaner]=get_temp_filename(tmp_pat);
    cosmo_map2fmri(ds,fn_orig);

    [fn_rs, cleaner2]=get_temp_filename(tmp_pat);

    % create command
    cmd=sprintf('3dresample -rmode NN -prefix %s -inset %s -orient %s',...
                fn_rs, fn_orig, orient);
    [success,output]=run_afni_command(cmd);
    if ~success
        error(output);
    end

    ds_rs=cosmo_fmri_dataset(fn_rs);

function temp_path=get_temp_path()
    c=cosmo_config();
    if ~isfield(c,'temp_path')
        error('temp_path is not set in cosmo_config');
    end
    temp_path=c.temp_path;

function [fn, cleaner]=get_temp_filename(pat)
    temp_path=get_temp_path();
    k=0;
    while true
        fn=fullfile(temp_path,sprintf(pat,k));
        if ~exist(fn,'file')
            cleaner=onCleanup(@()delete(fn));
            return;
        end
        k=k+1;
    end



