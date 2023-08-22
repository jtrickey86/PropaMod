% plotSSP
% Generate sound speed profiles for study sites.
% Configured for use with HYCOM's files
% Latitudes and longitudes are configured for Western Atlantic (WAT).
%
% AD: HYCOM data provides data points for every 1/12 degree. I believe
% that is at most every ~9.25 km. This MIGHT allow us to see significant
% differences in sound speed across a 20-km range, but given such a low
% resolution, I think those differences will be somewhat imprecise.
%
% HOW THE CODE EXTRAPOLATES DATA WHERE HYCOM HAS NONE
% The grid of regional SS data (cdat) has 40 depth levels. At each time
% point, this grid is regenerated for that time point. A secondary process
% takes out each level one by one, applies inpaint_nans to that level, then
% puts it back in the SS grid. The reason we apply inpaint_nans to each
% depth level individually is because the depth levels in the grid aren't
% evenly spaced, so extrapolating between them as though they are evenly
% spaced will be erroneous.
%
% This script produces 3 sound speed profiles for each site:
%   1. Average SSP across entire time period
%   2. SSP of the month with the fastest sound speed (maximum month)
%   3. SSP of the month with the slowest sound speed (minimum month)

clearvars
close all
%% Parameters defined by user

% Export directories
regAbrev = 'MHI'; % Abbreviation of region name
GDrive = 'L';     % GDrive drive
% HYCOM_saveDir_Local = 'I:\BellHopOutputs\GOM'; % Local save directory on your machine for HYCOM data
HYCOM_saveDir_Local = 'C:\Users\Selene.Fregosi\Documents\PropaMod\HYCOM_oceanState';
% HYCOM_saveDir_Final = [GDrive ':\My Drive\PropagationModeling\HYCOM_data\' regAbrev]; % Final GDrive save directory for HYCOM data
% SSP_saveDir =         [GDrive ':\My Drive\PropagationModeling\SSPs\' regAbrev]; % Final GDrive save directory for SSPs
HYCOM_saveDir_Final = ['C:\Users\Selene.Fregosi\Documents\PropaMod\HYCOM_oceanState'];
SSP_saveDir =         ['C:\Users\Selene.Fregosi\Documents\PropaMod\SSPs']; 

% Site Data: Path to Excel file with your sites' latitudes and longitudes. Use the Excel template in the repository.
siteCoordsFile = 'C:\Users\Selene.Fregosi\Documents\PropaMod\SiteCoords_gliders_MHI.xlsx';

% Range of data to download [Be mindful of the deepest bathymetry available
% in this region]
LatRange = [16 25];     % in degrees N (-80 S to 90 N). In order of S->N.
LonRange = [-161 -150];   % in degrees E (-180 W to 180 E). In order of W->E.

% Effort Period
Month_Start = '2022-04';  % First month of study period. Format as yyyy-MM.
Month_End = '2022-04';    % Final month of study period. Format as yyyy-MM.

plotInProcess = 1; % Monitor plotted SSPs as they are generated? 1=Y, 0=N. Program will run slower if this is on.
%% Load site coordinates
siteCoords = readtable(siteCoordsFile);
siteAbrev = cell2mat(siteCoords.Site);
Lat = siteCoords.Lat; Lon = siteCoords.Lon;

%% Download HYCOM data as mat files
sprintf('\n/ / / / / / / / / / STEP 1: HYCOM DOWNLOAD / / / / / / / / / /')
hycom_sampleMonths(Month_Start, Month_End, HYCOM_saveDir_Local, HYCOM_saveDir_Final, LatRange, LonRange)

%% Get list of fileNames in chronological order
MonthStart = [Month_Start(1:4) Month_Start(6:7)];
MonthEnd = [Month_End(1:4) Month_End(6:7)];
fileNames_all = ls(fullfile(HYCOM_saveDir_Final)); % File name to match. No need to modify this line.
fileNames_all = cellstr(fileNames_all);
fileNames_all(contains(fileNames_all, 'hycom', 'IgnoreCase', true),:) = [];
fileNames = fileNames_all(find(contains(fileNames_all,MonthStart)):find(contains(fileNames_all,MonthEnd),1,'last'),:);
fileNames = char(fileNames);

fileDatetimes = string(fileNames(:,1:11));
[~, file_sortOrder] = sort(fileDatetimes);
fileNames = fileNames(file_sortOrder, :); % Arrange fileNames in chronological order

%% Overarching loop runs through all timepoints requested
% Takes two time points at a time (the midnight and noon pair for each day)
% and calculates sound speed for the average

ALL_SSParray = nan(40,size(siteAbrev, 1),0.5*length(fileDatetimes));

sprintf('\n/ / / / / / / / / / STEP 2: MAKE SSPs / / / / / / / / / /')
for k = 1:2:length(fileNames(:,1))
    fileName_00 = fileNames(k,:);
    fileName_12 = fileNames((k+1),:);
    
    %% Load data
    load([HYCOM_saveDir_Final,'\', fileName_00]);
    D_00 = D;
    load([HYCOM_saveDir_Final,'\', fileName_12]);
    D_12 = D;
    
    temp_frame = (D_00.temperature + D_12.temperature)/2; % Get day's temperature matrix by averaging midnight and noon time points
    temp_frame = flip(permute(temp_frame, [2 1 3]),1); % To make maps work, swaps lat/long and flips lat
    
    sal_frame = (D_00.salinity + D_12.salinity)/2; % Get day's salinity matrix by averaging midnight and noon time points
    sal_frame = flip(permute(sal_frame, [2 1 3]),1);
    
    depth_frame = permute(repmat(D_00.Depth,1,length(D_00.Latitude),length(D_00.Longitude)), [2 3 1]); % Generates a depth matrix to match with sal and temp
    
    cdat = nan(length(D_00.Latitude),length(D_00.Longitude),length(D_00.Depth)); % Generates an empty frame to input sound speeds
    for i=1:(length(D_00.Latitude)*length(D_00.Longitude)*length(D_00.Depth)) % Only adds sound speed values ABOVE the seafloor
        if temp_frame(i) ~= 0 && sal_frame(i) ~= 0
            cdat(i) = salt_water_c(temp_frame(i),(-depth_frame(i)),sal_frame(i)); % Sound Speed data
        end
    end
    for lev=1:40 % Apply inpaint_nans to depth levels one at a time
        lev_extracted = cdat(:,:,lev);
        lev_extracted = inpaint_nans(lev_extracted);
        cdat(:,:,lev) = lev_extracted;
    end
    
    %% Generate SSPs
    
    depthlist = abs(transpose(D.Depth)); % List of depth values to assign to the y's
    LonE = Lon + 360; % Longitude in terms of 0E to 360E, rather than -180 E to 180 E
    siteCoords = [Lat, LonE];
    
    %MAKE FIGURES, and GENERATE TABLE OF SITE SSP VALUES
    SSP_array = double.empty(40,0);%SSP_table = depthlist.';
    
    if plotInProcess == 1
    plottimept = figure(200);
    plottimept_sup = uipanel('Parent',plottimept);
    timestamp = [fileName_00(1:4), '/', fileName_00(5:6), '/', fileName_00(7:8)];
    plottimept_sup.Title = ['Site SSPs | ' timestamp];
    set(gcf,'Position',[50 50 1500 700])
    end
    
    for i=1:size(siteAbrev, 1)
        numdepths = nan(1,length(depthlist));
        
        nearlats = knnsearch(D.Latitude,Lat(1),'K',4); %find closest 4 latitude values
        nearlats = sort(nearlats);
        nearlons = knnsearch(D.Longitude.',(360+Lon(1)),'K',4); %find closest 4 longitude values
        nearlons = sort(nearlons);
        cdat_site = cdat(nearlats, nearlons, :); % Create the site-specific subset of cdat
        
        for j=1:length(depthlist) %interpolate sound speed grid at each depth to infer sound speed values at site coordinates
            numdepths(j) = interp2(D.Longitude,flip(D.Latitude),cdat(:,:,j),siteCoords(i,2),siteCoords(i,1).');
        end
        
        if plotInProcess == 1
        subplot(1,size(siteAbrev, 1),i, 'Parent',plottimept_sup)
        plot(numdepths, -depthlist,'-.')
        ylim([-3200 0])
        title(char(siteAbrev(i,:)), 'Interpreter', 'none')
        if i == 1
            ylabel('Depth (m)')
        else
            set(gca,'YTickLabel',[])
        end
        if i == round(size(siteAbrev,1)/2)
            xlabel('Sound Speed (m/s)')
        end
        end
        
        %saveas(gcf,[saveDirectory,'\',char(plotDate),'_',char(siteabrev(i)),'_SSP'],'png');
        SSP_array(:,i) = numdepths;
    end
    if plotInProcess == 1
        drawnow
    end
    
    ALL_SSParray(:,:,(12*(str2double(fileNames(k,1:4))-str2double(fileNames(1,1:4)))+...
        str2double(fileNames(k,5:6))-str2double(fileNames(1,5:6))+1)) = SSP_array;
    % Array version of ALL_SSP - used for actual data assembly below
    
    SSP_table = array2table(SSP_array);
    table_varNames = cell(1,size(siteAbrev,1));
    for n = 1:size(siteAbrev,1)
        table_varNames(n) = {char(siteAbrev(n,:))};
    end
    SSP_table.Properties.VariableNames = table_varNames;
    
    ALL_SSP.(['M',fileNames(k,1:6)]) = SSP_table; % All the data from all time points and all sites is stored in ALL_SSP
    disp([fileNames(k,1:4) '/' fileNames(k,5:6) ' - Calculated SSPs and added to ALL_SSP as M' fileNames(k,1:6)])
        % NOTE - ALL_SSP isn't actually used hereafter, but could be helpful as a reference, if needed.
    
end
% ALL_SSParray(ALL_SSParray==0) = NaN;

% Get average SSP and stdev for each month
Month1 = datetime(MonthStart, 'InputFormat', 'yyyyMM', 'Format', 'MM'); % Month number of first month in the data
monthIndex = string(dateshift(Month1, 'start', 'month',0:(size(fileNames,1)/2 -1))); % Index to find which time points belong to each calendar month
for m = 1:12 % Now loop through months 1 to 12 and average each month's set of time points
    monthnum = string(sprintf('%02d', m));
    MoMeans.(char(strcat('M', monthnum))) = nanmean(ALL_SSParray(:,:,contains(monthIndex,monthnum)),3);
    MoStd.(char(strcat('M', monthnum))) = nanstd(ALL_SSParray(:,:,contains(monthIndex,monthnum)),0,3);
end

%% Interpolate full-depth SSPs and export data for each site

for b = 1:size(siteAbrev, 1)         % Generate subfolders for each site if they don't exist yet
    if ~exist(fullfile(SSP_saveDir, siteAbrev(b,:)), 'dir')
        mkdir(fullfile(SSP_saveDir, siteAbrev(b,:)))
    end
end

for b = 1:size(siteAbrev, 1)
    Site = siteAbrev(b,:);
    
    TotMean = mean(cat(3, MoMeans.M01, MoMeans.M02,MoMeans.M03,MoMeans.M04,MoMeans.M05,MoMeans.M06,...
        MoMeans.M07,MoMeans.M08,MoMeans.M09,MoMeans.M10,MoMeans.M11,MoMeans.M12), 3, 'omitnan'); % Average all 12 calendar months
    % Averages the 12 month averages instead of averaging all the
    % individual months, since some of the 12 months may be less represented
    TotStd = std(cat(3, MoMeans.M01, MoMeans.M02,MoMeans.M03,MoMeans.M04,MoMeans.M05,MoMeans.M06,...
        MoMeans.M07,MoMeans.M08,MoMeans.M09,MoMeans.M10,MoMeans.M11,MoMeans.M12), 0, 3, 'omitnan'); % SD of the 12 calendar months
    
    TotMeanfd = [(0:5000).' nan(1,5001).']; % Make an array for the full depth
    TotMeanfd((depthlist+1),2) = TotMean(:,b); % Bring in site-specific data
    TotMeanfd(:,2) = interp1((depthlist+1).', TotMeanfd((depthlist.'+1),2),1:length(TotMeanfd));
    
    SSPT = [(0:5000).',inpaint_nans(TotMeanfd(:,2))];
    SSPT = array2table(SSPT);
    SSPT.Properties.VariableNames = {'Depth' 'SS'};
    writetable(SSPT, [SSP_saveDir,'\', Site,'\', Site, '_SSP_Mean','.xlsx']) % Save overall average SSP
    disp(['Average annual SSP saved for ' Site])
    
    figure(b+200)
    plot(SSPT.SS,-SSPT.Depth)
    title(siteAbrev(b,:), 'Interpreter', 'none')
    xlim([1450,1560])
    set(gcf,'Position',[170*(b-1) 50 170 700])
    
end

%% Calculate the min and max months and produce the SSPs to save accordingly

testmean = nan(12,size(siteAbrev,1));
for month = 1:12
    testmean(month,:) = mean(MoMeans.(['M',num2str(sprintf('%02d', month))])([23 25 27:33],1:size(siteAbrev, 1)), 'omitnan');
end

extremeMonths = nan(length(siteAbrev(1,:)),2);
for i = 1:length(siteAbrev(:,1))
    extremeMonths(i,1) = find(testmean == min(testmean(:,i))) - 12*(i-1); % Min months stored in first column
    extremeMonths(i,2) = find(testmean == max(testmean(:,i))) - 12*(i-1); % Max months stored in second column
end

for i = 1:length(siteAbrev(:,1))
    Site = siteAbrev(i,:);
    
    minMo = extremeMonths(i,1);
    maxMo = extremeMonths(i,2);
    
    MeanSSP_minMo = MoMeans.(['M',num2str(sprintf('%02d', minMo))]); % Average sound speed profiles of the month with lowest sound speeds
    MoMeanfd = [(0:5000).' nan(1,5001).']; % Make an array for the full depth
    MoMeanfd((depthlist+1),2) = MeanSSP_minMo(:,i); % Drop the site-specific data into this array
    MoMeanfd(:,2) = interp1((depthlist+1).', MoMeanfd((depthlist.'+1),2),1:length(MoMeanfd));
    % Interpolate to get missing depths in between and extrapolate to get deeper depths
    SSPM = [(0:5000).',inpaint_nans(MoMeanfd(:,2))];
    SSPM = array2table(SSPM);
    SSPM.Properties.VariableNames = {'Depth' 'SS'};
    writetable(SSPM, [SSP_saveDir,'\', siteAbrev(i,:),'\', siteAbrev(i,:), '_SSPMmin_',num2str(sprintf('%02d', minMo)),'.xlsx']) % Save minimum month average SSP
    disp(['Average minimum month SSP saved for ' Site '. At this site, Month ' num2str(sprintf('%02d', minMo)) ' has the slowest average SSP.'])
    
    MeanSSP_maxMo = MoMeans.(['M',num2str(sprintf('%02d', maxMo))]); % Average sound speed profiles of the month with lowest sound speeds
    MoMeanfd = [(0:5000).' nan(1,5001).']; % Make an array for the full depth
    MoMeanfd((depthlist+1),2) = MeanSSP_maxMo(:,i); % Drop the site-specific data into this array
    MoMeanfd(:,2) = interp1((depthlist+1).', MoMeanfd((depthlist.'+1),2),1:length(MoMeanfd));
    % Interpolate to get missing depths in between and extrapolate to get deeper depths
    SSPM = [(0:5000).',inpaint_nans(MoMeanfd(:,2))];
    SSPM = array2table(SSPM);
    SSPM.Properties.VariableNames = {'Depth' 'SS'};
    writetable(SSPM, [SSP_saveDir,'\', siteAbrev(i,:),'\',siteAbrev(i,:), '_SSPMmax_',num2str(sprintf('%02d', maxMo)),'.xlsx']) % Save maximum month average SSP
    disp(['Average maximum month SSP saved for ' Site '. At this site, Month ' num2str(sprintf('%02d', maxMo)) ' has the fastest average SSP.'])
    
end