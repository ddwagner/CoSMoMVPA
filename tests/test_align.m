function test_suite=test_align
    initTestSuite;

function test_align_basics
    x=cosmo_synthetic_dataset('type','meeg','size','big');
    y=cosmo_slice(x,x.fa.chan<=6,2);
    orig_ds=cosmo_dim_transpose(y,'time');

    [nsamples,nfeatures]=size(orig_ds.samples);

    ds1=cosmo_slice(orig_ds,randperm(nsamples));
    ds2=cosmo_slice(orig_ds,randperm(nsamples));

    [mp,pm]=cosmo_align({ds1.sa.targets,ds1.sa.chunks,ds1.sa.time},...
                            {ds2.sa.targets,ds2.sa.chunks,ds2.sa.time});
    assertEqual(cosmo_slice(ds1,mp),ds2);
    assertEqual(cosmo_slice(ds2,pm),ds1);

    [mp,pm]=cosmo_align([2 3 4],[4 2 3]);
    assertEqual(mp,[3 1 2]);
    assertEqual(pm,[2 3 1]);


    [mp,pm]=cosmo_align({{'b','c','c'},[3 2 3]},...
                            {{'c','b','c'},[3 3 2]});
    assertEqual(mp,[3 1 2]);
    assertEqual(pm,[2 3 1]);

    % test structs
    p=struct();
    p.x={'b','c','c'};
    p.y=[3 2 3];
    q=struct();
    q.y=[3 3 2];
    q.x={'c','b','c'};
    [mp,pm]=cosmo_align(p,q);
    assertEqual(mp,[3 1 2]);
    assertEqual(pm,[2 3 1]);

    % test NaN
    [mp,pm]=cosmo_align([2 NaN 4],[4 2 NaN]);
    assertEqual(mp,[3 1 2]);
    assertEqual(pm,[2 3 1]);



    % test exceptions
    ds_small=cosmo_slice(ds1,1:nsamples-1);
    aet=@(varargin)assertExceptionThrown(@()...
                    cosmo_align(varargin{:}),'');
    aet(ds1,ds2);
    aet([2 3 4 3],[4 2 3 4]);
    aet([2 3 4 3],[4 2 3 4]);
    aet([2 3 4 3],[4 2 3]);
    aet([2 3 4],{[2,3,4],[2,3,4]});

    aet([2 3 NaN NaN],[2 3 NaN Inf]);
    aet([2 NaN 3],[4 2 NaN]);

    aet(struct,struct('a',1));
    aet(struct('a',1),1);

    aet({'b','c','d','d'},{'d','b','c','d'});



