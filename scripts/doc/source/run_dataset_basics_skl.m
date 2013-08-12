%% Dataset basics
% Set data path, load dataset, set targets and chunks, and add labels as
% sample attributes

% Set the data path (change cosmo_get_data_path if necessary)
data_path=cosmo_get_data_path('s01');

% Load dataset (and supply a mask file for 'vt')
% [your code here]

% Set the targets and the chunks
% [your code here]

% Add labels as sample attributes
% [your code here]
=======
labels = {'monkey','lemur','mallard','warbler','ladybug','lunamoth'}';
ds.sa.labels = repmat(labels,10,1)
% <<
>>>>>>> 868ef13bd03f668a468b65de5258afe8d4bddfc9:scripts/src/run_dataset_basics.m