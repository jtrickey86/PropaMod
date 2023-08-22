function hycom_sampleMonths(startMonth, endMonth, local_outpath, final_outpath, LatRange, LonRange)

% Function modified from script ext_hycom_gofs_3_1.m (developed by Dr. Ganesh Gopalakrishnan)
%   Utilizes ext_hycom_gofs_93_0.m (developed by Dr. Ganesh Gopalakrishnan)
%
% Please format start and end months as 'yyyy-MM'.
% Your local_outpath is a folder on your device. The data is saved here directly.
% Your final_outpath (optional) can be a folder on GDrive. The data is exported to here.
%
% hycom_sampleMonths.m is designed to sample HYCOM ocean state data from each month in a
% select time period. For each month, the first day of the month is first attempted.
% Both noon and midnight data must be collected. If this cannot be done, the script
% attempts to use the second day, then the third. If the third day has incomplete data,
% the month is excluded from the dataset.
% For a given run, the script will output a text file detailing months where the second
% day was attempted, months where the third day was attempted, and months that were
% excluded.

tic

opath = [local_outpath '\'];
msgbox(['HYCOM MOVED FROM GOMFS 3.0 (32 LEVLS) TO GOFS 3.1 (41 LEVELS)';...
	'                                                             ';...
	'HYCOM GOFS 3.0 extends only up to 2018-11-20                 ';...
	'NEW HYCOM is for every 3 hours!!!!!!                         ';...
	'GRID is changed for this experiment from GLBv0.08            ';...
	'                                                             ';...
	'Hindcast Data: Jul-01-2014 to Apr-30-2016                    ';...
	'https://tds.hycom.org/thredds/dodsC/GLBv0.08/expt_56.3       ';...
	'                                                             ';...
	'Hindcast Data: May-01-2016 to Jan-31-2017                    ';...
	'https://tds.hycom.org/thredds/dodsC/GLBv0.08/expt_57.2       ';...
	'                                                             ';...
	'Hindcast Data: Feb-01-2017 to May-31-2017                    ';...
	'https://tds.hycom.org/thredds/dodsC/GLBv0.08/expt_92.8       ';...
	'                                                             ';...
	'Hindcast Data: Jun-01-2017 to Sep-30-2017                    ';...
	'https://tds.hycom.org/thredds/dodsC/GLBv0.08/expt_57.7       ';...
	'                                                             ';...
	'Hindcast Data: Oct-01-2017 to Dec-31-2017                    ';...
	'https://tds.hycom.org/thredds/dodsC/GLBv0.08/expt_92.9       ';...
	'                                                             ';...
	'Hindcast Data: Jan-01-2018 to Feb-18-2020                    ';...
	'https://tds.hycom.org/thredds/dodsC/GLBv0.08/expt_93.0       ';...
	'                                                             ';...
	'Hindcast Data: Dec-04-2018 to Present *3-hourly*             ';...
	'https://tds.hycom.org/thredds/dodsC/GLBy0.08/expt_93.0       '], 'HYCOM - Info for user')

%% Determine data to download depending on the experiment
% GR = Grid Range
% How this section works:
% Your data will be downloaded as a grid of data points. However, because
% of variation in the latitudinal resolution and the longitudinal
% arrangement of the data (180W-180E or 0-360E) between experiments, the
% exact grid of data you need to download varies depending on the
% experiment. This section of the code translates your chosen latitude and
% longitude ranges to get the grids that are right for each experiment.
%   The max/min lats and max/min lons you chose may not match perfectly
% with the grid points available, so the code should round to the nearest
% grid point. (EX. if you request the minimum longitude 297E, the code will
% choose the grid points that match with 296.9600 since 297 isn't in the grid.)

% GLBv0.08 Lat Resolution
%   Resolution 0.08 degrees, for 40S-40N; 0.04 degrees, for 80-40 S and 40-90 N.
v008_lats = [-79.96:.04:-40, -39.92:.08:39.92, 40:.04:90];
v008_latGR = dsearchn(v008_lats.', LatRange(1)):dsearchn(v008_lats.', LatRange(2));

% GLBv0.08 Lon Resolution, Type A: Applies for expt_56.3, expt_57.2, and expt_57.7.
%   Resolution 0.08 degrees.
v008a_lons = -180:0.08:180;
v008a_lonGR = dsearchn(v008a_lons.', LonRange(1)):dsearchn(v008a_lons.', LonRange(2));
% GLBv0.08 Lon Resolution, Type B: Applies for expt_92.8, expt_92.9, and expt_93.0.
%   Resolution 0.08 degrees, in terms of 0-360E rather than 180W-180E.
v008b_lons = 0:0.08:360;
v008b_lonGR = dsearchn(v008b_lons.', LonRange(1)+360):dsearchn(v008b_lons.', LonRange(2)+360);

% GLBy0.08 Lat and Lon Resolution: The following applies for GLBy0.08, expt_93.0.
%   Lat Resolution 0.04 degrees
y008_lats = -79.96:.04:90;
y008_latGR = dsearchn(y008_lats.', LatRange(1)):dsearchn(y008_lats.', LatRange(2));
%   Lon Resolution 0.08 degrees, in terms of 0-360E, like GLBv0.08.
y008_lons = 0:0.08:360;
y008_lonGR = dsearchn(y008_lons.', LonRange(1)+360):dsearchn(y008_lons.', LonRange(2)+360);

% Depth: The depth grid is the same for all experiments.
depthGR = 0:1:39;

%% Time
formatTime = 'yyyy-MM-dd HH:mm:ss'; % formatTime = 'yyyy-mm-dd HH:MM:SS';
start_date = char(datetime([startMonth '-01'], 'InputFormat', 'yyyy-MM-dd', 'Format', formatTime));
end_date = char(datetime([endMonth '-01'], 'InputFormat', 'yyyy-MM-dd', 'Format', formatTime));

monthnum = between(datetime(start_date),datetime(end_date), 'months');
monthnum = split(monthnum, 'months');

%% Create empty time lists for second and third iterations, for files that can be removed, and for excluded months
daysToDelete = double.empty(1,0);   excludedMonths = double.empty(0,1);
time00_2 = []; time12_2 = [];       time00_3 = []; time12_3 = [];

%% start diary
fileOut = [opath 'hycom_download.log'];
diary( [fileOut]);
disp('==========================');
disp(fileOut)

time00_1 = datenum(dateshift(datetime(start_date),'start','month',0:monthnum));
time12_1 = datenum(dateshift(datetime(start_date),'start','month',0:monthnum)) + 0.5;

for itr = 1:3  % Loop through iterations

	if itr == 1
		time_1 = sort([time00_1 time12_1]); time = time_1;
	elseif itr == 2
		time_2 = sort([time00_2 time12_2]); time = time_2;
	elseif itr == 3
		time_3 = sort([time00_3 time12_3]); time = time_3;
	end
	nt = length(time);

	%% Loop through time points to download data
	for i = 1:nt % Loop through time points
		f1 = i;
		str_date = datestr(time(i),'yyyy-mm-dd HH:MM:SS');

		% there is big jump between two solutions, so using most in recent/latest solution
		eddate = datenum(date);
		stdate = datenum(str_date,'yyyy-mm-dd HH:MM:SS');

		if ((datenum(2014,7,1) >= stdate) || (stdate < datenum(2016,5,1))) % GLBv0.08 expt_56.3
			OpenDAP_URL = 'http://tds.hycom.org/thredds/dodsC/GLBv0.08/expt_56.3';
			xl = v008a_lonGR; yl = v008_latGR; zl = depthGR;
			ext_hycom_gofs_93_0(opath,f1,str_date,zl,yl,xl,OpenDAP_URL);
			%%GAP
		elseif ((datenum(2016,5,1) >= stdate) || (stdate < datenum(2017,2,1))) % GLBv0.08 expt_57.2
			OpenDAP_URL = 'http://tds.hycom.org/thredds/dodsC/GLBv0.08/expt_57.2';
			xl = v008a_lonGR; yl = v008_latGR; zl = depthGR;
			ext_hycom_gofs_93_0(opath,f1,str_date,zl,yl,xl,OpenDAP_URL);
			%%GAP
		elseif ((datenum(2017,2,1) >= stdate) || (stdate < datenum(2017,6,1))) % GLBv0.08 expt_92.8
			OpenDAP_URL = 'http://tds.hycom.org/thredds/dodsC/GLBv0.08/expt_92.8';
			xl = v008b_lonGR; yl = v008_latGR; zl = depthGR;
			ext_hycom_gofs_93_0(opath,f1,str_date,zl,yl,xl,OpenDAP_URL);

		elseif ((datenum(2017,6,1) >= stdate) || (stdate < datenum(2017,10,1)))
			OpenDAP_URL = 'http://tds.hycom.org/thredds/dodsC/GLBv0.08/expt_57.7'; % GLBv0.08 expt_57.7
			xl = v008a_lonGR; yl = v008_latGR; zl = depthGR;
			ext_hycom_gofs_93_0(opath,f1,str_date,zl,yl,xl,OpenDAP_URL);
			%%GAP
		elseif ((datenum(2017,10,1) >= stdate) || (stdate < datenum(2018,1,1)))
			OpenDAP_URL = 'http://tds.hycom.org/thredds/dodsC/GLBv0.08/expt_92.9'; % GLBv0.08 expt_92.9
			xl = v008b_lonGR; yl = v008_latGR; zl = depthGR;
			ext_hycom_gofs_93_0(opath,f1,str_date,zl,yl,xl,OpenDAP_URL);

		elseif ((datenum(2018,1,1) >= stdate) || (stdate <= datenum(2019,1,1)))
			OpenDAP_URL = 'http://tds.hycom.org/thredds/dodsC/GLBv0.08/expt_93.0'; % GLBv0.08 expt_93.0
			xl = v008b_lonGR; yl = v008_latGR; zl = depthGR;
			ext_hycom_gofs_93_0(opath,f1,str_date,zl,yl,xl,OpenDAP_URL);

		elseif ((datenum(2019,1,1) >= stdate) || (stdate <= eddate))
			OpenDAP_URL = 'http://tds.hycom.org/thredds/dodsC/GLBy0.08/expt_93.0'; % GLBy0.08 expt_93.0
			xl = y008_lonGR;  yl = y008_latGR; zl = depthGR;    % GLBy0.08 has a different GRID!
			ext_hycom_gofs_93_0(opath,f1,str_date,zl,yl,xl,OpenDAP_URL);
		end

		% If a file couldn't be downloaded, add serial number of the following
		% day to the list of dates for the next iteration
		expected_FileName = [num2str(sprintf('%04d', i)), '_', char(datetime(str_date, 'Format', 'yyyyMMdd')), 'T' char(datetime(str_date, 'Format', 'HHmmSS')) '.mat'];
		expected_FilePath = fullfile(opath, expected_FileName);

		if ~exist(expected_FilePath, 'file')
			str_dateStart = dateshift(datetime(str_date), 'start', 'day');
			if itr == 1
				disp('Complete data cannot be generated for this date. Will attempt to use second day of month.')
				if isempty(time00_2) || ~any(contains(string(time00_2), string(datenum(str_dateStart)+1))) % Avoid duplicate dates in 2nd iteration
					time00_2 = [time00_2 datenum(str_dateStart)+1];
					time12_2 = [time12_2 datenum(str_dateStart)+1.5];
				end
			elseif itr == 2
				disp('Complete data cannot be generated for this date. Will attempt to use third day of month.')
				if isempty(time00_3) || ~any(contains(string(time00_3), string(datenum(str_dateStart)+1))) % Avoid duplicate dates in 3rd iteration
					time00_3 = [time00_3 datenum(str_dateStart)+1];
					time12_3 = [time12_3 datenum(str_dateStart)+1.5];
				end
			elseif itr == 3
				disp(['Complete data cannot be generated for this date. This month will not be included in downstream calculations.'])
				excludedMonths = [excludedMonths string(datetime(datenum(str_dateStart), 'ConvertFrom', 'datenum', 'Format', 'yyyy-MM'))];
			end
			daysToDelete = [daysToDelete string(datetime(datenum(str_dateStart), 'ConvertFrom', 'datenum', 'Format', 'yyyyMMdd'))]; % 'Label' this date for deletion
		else
			disp(['Successfully made file: ' str_date])
		end

		% As mentioned above, the start of 2019 involves a grid change.
		% Thus, 01/01/2019 00:00:00 and 12:00:00 have different dimensions
		% and aren't compatible (e.g. for finding average). So, manually
		% mark 01/01/2019 for deletion and add 01/02 to second iteration.
		if strcmp(str_date, '2019-01-01 00:00:00')
			str_dateStart = dateshift(datetime(str_date), 'start', 'day');
			time00_2 = [time00_2 datenum(str_dateStart)+1];
			time12_2 = [time12_2 datenum(str_dateStart)+1.5];
			daysToDelete = [daysToDelete string(datetime(datenum(str_dateStart), 'ConvertFrom', 'datenum', 'Format', 'yyyyMMdd'))]; % 'Label' this date for deletion
			disp('2019-01-01 is automatically excluded from the data. Will use 2019-01-02 instead.')
		end

	end % End loop through time points

end % End loop through iterations

diary off;

% Wrap up by deleting partial data from unused days
filesList = ls(opath);
if ~isempty(daysToDelete)
	filesToDelete = filesList(contains(ls(opath), string(daysToDelete)),:);
	for d = 1:size(filesToDelete, 1)
		delete(fullfile(opath,strcat(filesToDelete(d,:))))
	end
	disp('Incomplete data deleted.')
else
	disp('No incomplete data to delete.')
end

runtime = toc; %Get run time

%% Generate report of run for user -- This doesn't appear to be functioning correctly

txtFileName = ['HYCOM_sM_Report_' char(datestr(datetime('now'), 'yyyymmdd_HHMMSS')) '.txt'];
paramfile = fullfile(opath, txtFileName);
fileid = fopen(paramfile, 'w');
fclose(fileid);
fileid = fopen(paramfile, 'at');
fprintf(fileid, ['hycom_sampleMonths.m output - Report for User'...
	'\nCompleted on ' char(datestr(datetime('now'), 'yyyy-mm-dd HH:MM:SS'))...
	'\n\nRegion:\t24-44N, and -63 - -82W (278-297E)' ...
	'\n\nTime Period Covered:\t' char(datetime(datenum(start_date), 'ConvertFrom', 'datenum', 'Format', 'yyyy-MM-dd')) ' to ' char(datetime(datenum(end_date), 'ConvertFrom', 'datenum', 'Format', 'yyyy-MM-dd'))...
	'\n\nFor the following months, first-day data was missing or incomplete. The second day was attempted. For 2019-01, the second day is used automatically.\n' char(datetime(time00_2, 'ConvertFrom', 'datenum', 'Format', 'yyyy-MM'))...
	'\n\nFor the following months, second-day data was also missing or incomplete. The third day was attempted.\n' char(datetime(time00_3, 'ConvertFrom', 'datenum', 'Format', 'yyyy-MM'))...
	'\n\nFor the following months, third-day data was also missing or incomplete. These months have been excluded from the data.\n' char(excludedMonths)]);
fclose(fileid);

%% Rename files without numeric prefix
filesList_new = ls(fullfile(opath));
for k = 1:size(filesList_new,1)
	if contains(filesList_new(k,:), '.mat')
		if contains(filesList_new(k,:), '_')
			movefile(fullfile(opath, filesList_new(k,:)), fullfile(opath, filesList_new(k,6:end)))
		end
	end
end

%% Move files to final directory, if it is different from local directory
if exist(final_outpath) && ~strcmp(local_outpath, final_outpath)
	filesList_new = ls(fullfile(opath));
	for k = 1:size(filesList_new,1)
		movefile(fullfile(opath, filesList_new(k,:)),...
			fullfile(final_outpath, filesList_new(k,:)))
	end
end