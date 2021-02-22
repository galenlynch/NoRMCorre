% demo file for applying the NoRMCorre motion correction algorithm on
% 1-photon widefield imaging data using low memory (good for long datasets)
% Example file is provided from the miniscope project page
% www.miniscope.org
function [M1, shifts1, template1, Mr, options_r] = ...
         glynch_1p_low_ram(datname, nx, ny, nf, writedir, varargin)

persistent p;
if isempty(p)
    p = inputParser();
    addParameter(p, 'gSig', 10);
    addParameter(p, 'bin_width', 200);
    addParameter(p, 'max_shift', 20);
    addParameter(p, 'iter', 1);
    addParameter(p, 'correct_bidir', false);
    addParameter(p, 'bit_format', 'uint16');
    addParameter(p, 'chunksize', 5000);
    addParameter(p, 'force', false);
end
parse(p, varargin{:});
Options = p.Results;

%% perform deblurring/high pass filtering
% The function does not load the whole file in memory. Instead it loads
% chunks of the file and then saves the high pass filtered version in a
% h5 file.

gSig = Options.gSig;
gSiz = 3*gSig;
psf = fspecial('gaussian', round(2*gSiz), gSig);
ind_nonzero = (psf(:)>=max(psf(:,1)));
psf = psf-mean(psf(ind_nonzero));
psf(~ind_nonzero) = 0;   % only use pixels within the center disk

mm = memmapfile(datname, 'Format', {Options.bit_format, [nx, ny, nf], 'x'});
rawdata = mm.Data.x;
[~, file_name, ext] = fileparts(datname);
h5_name = fullfile(writedir, [file_name,'_filtered_data.h5']);
if isfile(h5_name)
    if Options.force
        delete(h5_name);
    else
        error('%s already exists and ''force'' was not specified', h5_name);
    end
end
cnt = 1;
while cnt < nf  % read filter and save file in chunks
    stopframe = min(nf, cnt + Options.chunksize - 1);
    Yf = single(rawdata(:, :, cnt:stopframe));
    if isempty(Yf)
        break
    else
        Y = imfilter(Yf, psf, 'symmetric');
        clear Yf;
        saveash5(Y, h5_name);
        cnt = stopframe + 1;
        clear Y;
    end
    disp(cnt)
end

%% first try out rigid motion correction
    % exclude boundaries due to high pass filtering effects
options_r = NoRMCorreSetParms('d1', nx, 'd2', ny, ...
                              'bin_width', Options.bin_width, ...
                              'max_shift', Options.max_shift, ...
                              'iter', Options.iter, ...
                              'correct_bidir', Options.correct_bidir);

%% register using the high pass filtered data and apply shifts to original data
[M1, shifts1, template1] = normcorre_batch(h5_name, options_r); % register filtered data
    % exclude boundaries due to high pass filtering effects

% if you save the file directly in memory make sure you save it with a
% name that does not exist. Change options_r.tiff_filename
% or options_r.h5_filename accordingly.

Mr = apply_shifts(name, shifts1, options_r); % apply shifts to full dataset

% you can only save the motion corrected file directly in memory by
% setting options_r.output_type = 'tiff' or 'h5' and selecting an
% appropriate name through options_r.tiff_filename or options_r.h5_filename

end
