%VZ: Modified from Eric Snyder's makeEnv.m code

function makeEnv(filepath, filename, z, ssp, SD, RD, NR, RR, modelType)



fpn = fullfile(filepath, [filename, '.env']);

% make file or erase current contents of file:
fid = fopen(fpn, 'w');
fclose(fid);

% open file to append contents
fid = fopen(fpn, 'at');

% line 1: title
fprintf(fid, ['''', filename, '''']);
fprintf(fid, '\t!TITLE\n');

% line 2: freq
fprintf(fid, '12000\t!Freq (Hz)\n');

% line 3: No. of media
fprintf(fid, '1\t! NMEDIA\n');

% line 4: interpolation type
fprintf(fid, '''SVW''\t! SSPOPT (Analytic or C-linear interpolation)\n');

% line 5: Bottom depth, number of depth values
fprintf(fid, '%d  0.0  %.3f\t! Depth of bottom (m)\n', 2, max(z));

% lines 6 to 6 + N: depth and ssp
fprintf(fid, '%d\t%.6f\t/ \n', z(1), ssp(1));
for nz = 2:length(z)
    fprintf(fid, '%.3f\t%.6f\t/ \n', z(nz), ssp(nz));
end

% Bottom half-space properties
fprintf(fid, '''A*'' 0.0\n');
fprintf(fid, ' 5000.0  %.3f  0.0 1.5 0.5  /\n', max(ssp)*1.01);

% Number of source depths (hydrophone location)
fprintf(fid, '%d\t! No. of SD\n', length(SD));

% Source depths
fprintf(fid, '%.4f  ', SD);
fprintf(fid, '/\t! SD\n');

% Number of receiver depths (ship locations)
fprintf(fid, '%d\t! No. of RD\n', length(RD));

% receiver depths
fprintf(fid, '%.4f  ', RD);
fprintf(fid, '/\t! RD\n');

% Number of receiver ranges (ship locations)
fprintf(fid, '%d\t! No. of RR\n', NR);

% Source depths
fprintf(fid, '%.4f  ', RR./1000);
fprintf(fid, '/\t! RR\n');

% model type
fprintf(fid, ['''', modelType, '''\n']);

% No. of beams
switch modelType
    case 'A'
        fprintf(fid, '0\n');
    case 'E'
        fprintf(fid, '2001\n')
    case 'C'
        fprintf(fid, '0\n');
end

% Beam angles
fprintf(fid, '-90  90 /\n');

% Step, ZBOX, RBOX (don't really know what this does)
fprintf(fid, '50  2000 101.0');

fclose(fid);