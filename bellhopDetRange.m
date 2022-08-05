% code to calculate detection range around HARP
% Vanessa ZoBell June 9, 2022
% Edited by AD and NP
%
% Data needed to run:
% bathymetry data (sbc_bathymetry.txt)
% sound speed profiles
%
% Variables to change: 
% fpath: path to where the bellhop code is.
%   - makeBTY.m 
%   - makeENV.m
%   - read_shd.m
% Bath: Path and file to your bathymetry file.
% SSP_WAT: Path and file to your sound speed profile data.

% This script will:
        % Construct sound propagation radials around your site with your
        % specified parameters
        % Save a .txt file w/ your selected parameters in Export directory
        % and plot directory
        % Save .bty, .env, .shd, and .prt files to intermediate directory
        % Move these outputs to the Export directory
        % Generate radial and polar plots and save to Export directory

clear variables
clear all
%% Define global vars
% These are being called in the loop but are not functions
global rangeStep
global lat
global lon
global z
global lati
global loni
global rad
global radStep
global depthStep

%% Run settings - What would you like to do?
runSettings = 1;
% 1 = I want to create a completely new set of radials based on new
%     parameters, and save plots and the pDetSim workspace. (If selecting
%     this option, please edit the settings below before hitting Run.)
% 2 = I want to make plots and/or save the pDetSim workspace for an
%     existing set of radials. (You will be prompted to input the path of
%     the respective timestamp folder.)

% Note from AD 8/5/22 - Ultimately this code shouldn't really be necessary.
% As long as the code to make and save plots and pDetSim workspace is sound, they should get
% output just fine and user shouldn't have to do it again

%% Params defined by user + Info for user (for runSettings Option 1 ONLY)
% if runSettings == 1
   
author = 'AD'; % Your name/initials here. This will be included in the .txt output.
userNote = 'Hello, whale!';
    % Optionally, include a note for yourself or other users. This will be
    % included in the .txt output.

% CONFIGURE PATHS - INPUT AND EXPORT
Site = 'NC';
Region = 'WAT';

%outDir = [fpath, '\Radials\', SITE]; % EDIT - Set up Google Drive folder - for loading in items and saving
bellhopSaveDir = 'C:\Users\HARP\Documents\PropMod_Radials_Intermediate'; %Aaron's Computer % Intermediate save directory on your local disk
% bellhopSaveDir = 'E:\BellHopOutputs'; %Natalie's Computer % Intermediate save directory on your local disk
Gdrive = 'G';
fpath = [Gdrive, ':\My Drive\PropagationModeling']; % Input directory
    % fpath must contain:   % bathymetry file: \Bathymetry\bathy.txt
                            % Site SSP data: \SSPs\SSP_WAT_[Site].xlsx
saveDir = [fpath, '\Radials\', Site]; % Export directory
% intermedDir = 'C:\Users\HARP\Documents\PropMod_Radials_Intermediate'; % Intermediate save directory on your local disk
% intermedDir = 'E:\BellHopOutputs\PropIntermediate'; %For Natalie's computer

SSPtype = 'Mean'; % Indicate your SSP type. 'Mean' = Overall mean, 'Mmax' = Month w/ max SS, 'Mmin' = Month w/ min SS.

% Note to self to have smth in plotSSP that exports the examined effort
% period and other relevant deets so they can be exported in the info file
% here

% SPECIFY PARAMETERS FOR INPUT

SL = 220; % Source Level
SD = 800; % Source depth
hlat = 39.8326; % hydrophone lat
hlon = -69.9800; % hydrophone long
hdepth = 960; % hydrophone depth
freq = 12000; % frequency of source
% freq = {8000 9000 10000}; %adjust the code so that you can loop through multiple peak frequencies

% CONFIGURE OUTPUT RANGE AND RESOLUTION
total_range = 40000;    % Radial range around your site, in meters
rangeStep = 10;         % Range resolution
depthStep = 10;         % Depth resolution
numRadials = 36;        % Specify number of radials - They will be evenly spaced.
    % Keep in mind, 360/numRadials = Your angular resolution.
nrr = total_range/rangeStep; %total # of range step output to be saved for pDetSim

% CONFIGURE PLOT OUTPUT
generate_RadialPlots = 1; % 1 = Yes, generate radial plots;  0 = No, do not generate radial plots
generate_PolarPlots = 1; % 1 = Yes, generate polar plots;  0 = No, do not generate polar plots

RL_threshold = 125; % Threshold below which you want to ignore data; will be plotted as blank (white space)
RL_plotMax = 200; % Colorbar maximum for plots; indicates that this is the max expected RL

% Polar Plots
makeDepthPlots = [150, 50, 1200]; % [min depth, step size, max depth] - we should try deeper than 800...maybe 1200m?

% Radial Plots    % THIS CAN BE PHASED OUT -- Code has been updated to just plot every radial it makes data for.
numRadial_Plot = 4; % make it so the user only has to choose the number of radial plots they want
% vvvv move this to the radial plot section and don't hard code it
makeRadialPlots = [0,10,350]; % [first radial to plot, step size, last radial to plot] can you add some more notes about this one please?

% end

%% If runSettings Option 2 selected: Prompt folder selection and import settings (may need some mending to generalize for other users besides myself)
% if runSettings == 2
% requestFolder = input('What is the path for the GDrive folder with your data?\n', 's');
% Site = input('What site is this data for? (2-letter abbreviation)\n', 's');
% 
% Gdrive = requestFolder(1);
% fpath = [Gdrive, ':\My Drive\PropagationModeling']; % Input directory
%     % fpath must contain:   % bathymetry file: \Bathymetry\bathy.txt
%                             % Site SSP data: \SSPs\SSP_WAT_[Site].xlsx
% saveDir = [fpath, '\Radials\', Site]; % Export directory
% % intermedDir = 'C:\Users\HARP\Documents\PropMod_Radials_Intermediate'; % Intermediate save directory on your local disk
% % intermedDir = 'E:\BellHopOutputs\PropIntermediate'; %For Natalie's computer
% 
% timestamp_currentrun = requestFolder(end-11:end);
% userParamsFile = fullfile(requestFolder, [timestamp_currentrun, '_Input_Parameters.txt']);
% 
% userParamsFileID = fopen(userParamsFile, 'r');
% userParams = fscanf(userParamsFileID, '%c');
% 
% SSPtype = str2double(userParams(strfind(userParams, 'SSPtype')+7:strfind(userParams, 'HYDROPHONE')-1));
% 
% SL = str2double(userParams(strfind(userParams, 'SL')+2:strfind(userParams, 'SD')-1));
% SD = str2double(userParams(strfind(userParams, 'SD')+2:strfind(userParams, 'hlat')-1));
% hlat = str2double(userParams(strfind(userParams, 'hlat')+4:strfind(userParams, 'hlon')-1));
% hlon = str2double(userParams(strfind(userParams, 'hlon')+4:strfind(userParams, 'hdepth')-1));
% hdepth = str2double(userParams(strfind(userParams, 'hdepth')+6:strfind(userParams, 'freq')-1));
% freq = str2double(userParams(strfind(userParams, 'freq')+4:strfind(userParams, 'RANGE & RESOLUTION')-1));
% 
% totalRange;
% rangeStep;
% radStep;
% depthStep;
% nrr = total_range/rangeStep;
% 
% generate_PolarPlots;
% generate_RadialPlots;
% RL_threshold; % Threshold below which you want to ignore data; will be plotted as blank (white space)
% RL_plotMax; % Colorbar maximum for plots; indicates that this is the max expected RL
% makeDepthPlots; % [min depth, step size, max depth] - we should try deeper than 800...maybe 1200m?
% numRadial_Plot; % make it so the user only has to choose the number of radial plots they want
% % vvvv move this to the radial plot section and don't hard code it
% makeRadialPlots; % [first radial to plot, step size, last radial to plot] can you add some more notes about this one please?
% 
% 
% end
%% Make new folder w/in bellhopSaveDir for this run's files (for runSettings Option 1)
% if runSettings == 1
timestamp_currentrun = datestr(datetime('now'), 'yymmddHHMMSS');
intermedDir = [bellhopSaveDir, '\' timestamp_currentrun];
mkdir(intermedDir);
% This prevents file overwriting, if you are running bellhopDetRange.m multiple
% times in parallel on the same computer.
% end

%% Bathymetry 
disp('Loading bathymetry data...') % Read in bathymetry data
tic
Bath = load([fpath, '\Bathymetry\bathy.txt']);
lon = Bath(:,2);    % vector for longitude
lat = Bath(:,1);    % vector for latitude
z = Bath(:,3);      % vector for depth (depth down is negative)
z = -z;             % Make depth down positive
toc
%% Sound Speed Profiles
SSPfolderCode = find(contains(ls(fullfile(fpath,'SSPs',Site)), SSPtype)); % Select SSP file based on user input
SSPfolder = ls(fullfile(fpath,'SSPs',Site));
SSPfile = SSPfolder(SSPfolderCode,:);
SSPfile(find(SSPfile==' ')) = [];

if strcmp(SSPtype, 'Mmax')        % Get month being examined to report in the output info file, if applicable
    SSPmoReporting = num2str(SSPfile(12:13));
elseif strcmp(SSPtype, 'Mmin')
    SSPmoReporting = num2str(SSPfile(12:13));
elseif strcmp(SSPtype, 'Mean')
    SSPmoReporting = 'Not applicable';
end

SSP = readtable(fullfile(fpath,'SSPs',Site,SSPfile)); % read the SSP file
NCSSPcoarse = [SSP.Depth SSP.SS]; % pull out the SSP for the specific site of interest 
idxNan = isnan(NCSSPcoarse(:, 2)); %identify any NANs
NCSSPcoarse(idxNan, :) = []; %remove NANs

vq = interp1(NCSSPcoarse(:, 1), NCSSPcoarse(:, 2), 1:1:NCSSPcoarse(end, 1)); % Fill in missing depths - every 1 m
NCSSP = [1:1:NCSSPcoarse(end, 1); vq]';
%% Hydrophone location and depth
% Center of source cell
hydLoc = [hlat, hlon, hdepth];

% Radial intervals and length
radStep = 360/numRadials;           % Angular resolution (i.e. angle between radials)
radials = 0:radStep:(360-radStep);  % radials in #-degree interval (# is in radStep)
dist = (total_range/1000);          % distance in km to farthest point in range
distDeg = km2deg(dist);             % radial length in degrees

% Source Depth
disp(['Source depth: ', num2str(SD), ' m'])
RD = 0:rangeStep:1000;              % Receiver depth (it's set to a 1000 here, but in the 'Build Radial' loop, RD goes to the maximum depth of the bathymetry
r = 0:rangeStep:total_range;        % range with steps
rr = r';                            % output to be saved for pDetSim

%% Before generating radial plots, set up plot save directory here:
if runSettings == 1
fpath_plotSub = [fpath, '\Plots\' Site '\' timestamp_currentrun];
mkdir(fpath_plotSub);
end

%% Build Radials
% Note: this loop will re-write the existing files in the folder if you do not
% create a subfolder using the above section of the code (titled: Make new
% folder w/in bellhopSaveDir for this run's files)

%if runSettings == 1
    
disp('General setup complete. Beginning radial construction...')
tic
for rad = 1:length(radials)
    disp(['Constructing Radial ' num2str(sprintf('%03d', radials(rad))), ':'])
    
    % gives lat lon point total range (km) away in the direction of radials from source center
    [latout(rad), lonout(rad)] = reckon(hydLoc(1, 1), hydLoc(1, 2), distDeg, radials(rad),'degrees');
    
    % RANGE STEP, interpolating a line from the center point to the point
    % at edge of circle
    lati(rad, :) = linspace(hydLoc(1, 1), latout(rad), length(0:rangeStep:total_range));
    loni(rad, :) = linspace(hydLoc(1, 2), lonout(rad), length(0:rangeStep:total_range));
    
    % Make bathymetry file (to be used in BELLHOP)
    disp(['Making bathymetry file for Radial ' num2str(sprintf('%03d', radials(rad))) '...'])
    tic
    [Range, bath] = makeBTY(intermedDir, ['Radial_' num2str(sprintf('%03d', radials(rad)))],latout(rad), lonout(rad), hydLoc(1, 1), hydLoc(1, 2)); % make bathymetry file
    bathTest(rad, :) = bath; % this is only used to plot the bathymetry if needed 
    RD = 0:rangeStep:max(bath); % Re-creates the variable RD to go until the max depth of this specific radial
    toc
   
    % make sound speed profile the same depth as the bathymetry
    zssp = 1:1:max(bath)+1;
    ssp = NCSSP(1:length(zssp), 2);

    %START LOOP FOR PEAK FREQUENCY HERE - be mindful of not saving the env
    %and bellhop output files over one another (either use a different
    %folder or change file name)
        % AD - made partial progress on this; will modify whole script to have 3
        % different intermediate directories and three output directories,
        % one per frequency
    
    for freqi = 1:length(freq)
    % Make environment file (to be used in BELLHOP)
    disp(['Making environment file for Radial ', num2str(sprintf('%03d', radials(rad))),', Frequency ', num2str(sprintf('%06d', freq(freqi))),' Hz...'])   % Status update
    makeEnv(intermedDir, ['Radial_' num2str(sprintf('%03d', radials(rad)))], freq, zssp, ssp, SD, RD, length(r), r, 'C'); % make environment file
    
    % Run BELLHOP
    disp(['Running Bellhop for Radial ', num2str(sprintf('%03d', radials(rad))),', Frequency', freq(freqi),'...']) % Status update
    tic
    bellhop(fullfile(intermedDir, ['Radial_' num2str(sprintf('%03d', radials(rad)))])); % run bellhop on env file
    toc
    end
    
    clear Range bath
    
    %% Generate radial plots
    if generate_RadialPlots == 1
    [PlotTitle, PlotType, freqVec, freq0, atten, Pos, pressure ] = read_shd([intermedDir, ['\Radial_' num2str(sprintf('%03d', radials(rad))) '.shd']]);
    PLslice = squeeze(pressure(1, 1,:,:));
    PL = -20*log10(abs(PLslice));
    
    [x1,y1] = meshgrid(1:rangeStep:(rangeStep*size(PL,2)),1:depthStep:(depthStep*size(PL,1)));
    [xq1,yq1] = meshgrid(1:(rangeStep*size(PL,2)),1:(depthStep*size(PL,1)));
    zq = interp2(x1,y1, PL,xq1, yq1);
    
    figure(2000+radials(rad))
    RL_radiii = SL - zq;
    RL_radiii(RL_radiii < RL_threshold) = NaN;
    ye_olde_whale = pcolor(RL_radiii(:,:)); % RL_radxxx is recieved level for the given radial
    axis ij
    set(ye_olde_whale, 'EdgeColor','none')
    colormap(jet)
    plotbty([intermedDir, '\Radial_',num2str(sprintf('%03d', radials(rad))),'.bty'])
    title([Site,' Radial', num2str(sprintf('%03d', radials(rad)))])
    colorbar
    saveas(ye_olde_whale,[fpath_plotSub,'\',Site,'_',num2str(sprintf('%03d', radials(rad))),'_RLRadialMap.png'])
    end

end
disp('Completed constructing all radials.')
toc

% end

%% Save User-input params to a text file; move this after SSP and include SSP that was inputted into that run (file name and the actual SSP)
SSP_Reporting = (table2array(SSP)).';

paramfile = fullfile(intermedDir, [timestamp_currentrun,'_Input_Parameters.txt']);
fileid = fopen(paramfile, 'w');
fclose(fileid);
fileid = fopen(paramfile, 'at');
fprintf(fileid, ['User Input Parameters for Run ' timestamp_currentrun...
    '\n\nCreated by\t' author '\nDateTime\t' timestamp_currentrun '\nUser Note' userNote...
    '\n\nSite\t' Site '\nRegion\t' Region ...
    '\n\nSSP INPUT\nFile Name\t' SSPfile, '\nSSP Type\t' SSPtype '\nMonth\t' SSPmoReporting...
    '\n\nHYDROPHONE PARAMETERS\nSL\t' num2str(SL) '\nSD\t' num2str(SD) '\nhlat\t' num2str(hlat) '\nhlon\t' num2str(hlon) '\nhdepth\t' num2str(hdepth) '\nFrequency\t' num2str(freq)...
    '\n\nRANGE & RESOLUTION\nRange\t' num2str(total_range) '\nRange Step\t' num2str(rangeStep) '\nNumber of Radials\t' num2str(numRadials) '\nRad Step\t' num2str(radStep) '\nDepth Step\t' num2str(depthStep)...
    '\n\nPLOT GENERATION\nGenerate Polar Plots\t' num2str(generate_PolarPlots) '\nGenerate Radial Plots\t' num2str(generate_RadialPlots)...
    '\nRL Threshold\t' num2str(RL_threshold) '\nRL Plot Maximum\t' num2str(RL_plotMax) '\nDepth Levels\t' num2str(makeDepthPlots) '\nRadial Plots\t' num2str(makeRadialPlots)...
    '\n\n\nSSP\nDepth\tSound Speed']);
fprintf(fileid, '\n%4.0f\t%4.11f', SSP_Reporting);
fclose(fileid);
copy(paramfile,[fpath_plotSub, '\' timestamp_currentrun, '_Input_Parameters.txt']);

%% Copy files to final export directory
% Include a check that ensures the files in the export directory aren't screwed up...
% Since the process did take a while to run
allFiles = ls(fullfile(intermedDir,'*Radial*'));
saveDir_sub = [saveDir, '\' timestamp_currentrun];
mkdir(saveDir_sub);
for k = 1:length(allFiles)
    copyfile(fullfile(intermedDir,allFiles(k,:)),fullfile(saveDir_sub, allFiles(k,:)));
    disp([allFiles(k,:), ' copied to new subfolder in GDrive export directory'])
end
copyfile(paramfile,fullfile(saveDir_sub, [timestamp_currentrun,'_Input_Parameters.txt']))

%% Generate Polar Plots
if generate_PolarPlots == 1

% POLAR PLOTS
% join this to the loop above keep the if generate plot check
disp(['Now generating polar plots between depths ' num2str(makeDepthPlots(1)) 'm and ' ...
    num2str(makeDepthPlots(3)) 'm, with interval ' num2str(makeDepthPlots(2)) 'm'])
pause(1)
for plotdepth = makeDepthPlots(1):makeDepthPlots(2):makeDepthPlots(3)
for rad = 1:length(radials)
    [PlotTitle, PlotType, freqVec, freq0, atten, Pos, pressure] = read_shd([intermedDir, '\', ['Radial_' num2str(sprintf('%03d', radials(rad))) '.shd']]);
    PLslice = squeeze(pressure(1, 1,:,:));
    PL = -20*log10(abs(PLslice));
    
    [x1,y1] = meshgrid(1:rangeStep:(rangeStep*size(PL,2)),1:depthStep:(depthStep*size(PL,1)));
    [xq1,yq1] = meshgrid(1:(rangeStep*size(PL,2)),1:(depthStep*size(PL,1)));
    zq = interp2(x1,y1, PL,xq1, yq1);
    
    %save radial depth
    rd_inter = Pos.r.z;
    
    PLiii(rad, :) = zq(plotdepth, :); % Save PL along depth iii meters, the depth that is currently being plotted
    
    clear zq yq1 xq1 x1 y1 
    disp(['Working on Polar plot w/ Depth ' num2str(plotdepth) ': Radial ' num2str(sprintf('%03d', radials(rad)))])
end

PLiii(isinf(PLiii)) = NaN;
PLiii(PLiii > RL_threshold) = NaN; %PLxxx > 125 == NaN; %AD - what is this line for
RLiii = SL - PLiii;
RLiii(RLiii < RL_threshold) = NaN; 

R = 1:1:length(RLiii(1,:));
figure(1000 + plotdepth)
[Radiance, calbar] = polarPcolor(R, [radials 360], [RLiii;NaN(1,length(RLiii(1,:)))], 'Colormap', jet, 'Nspokes', 7);
set(calbar,'location','EastOutside')
caxis([RL_threshold RL_plotMax]);
yticks(0:60:300)
set(get(calbar,'ylabel'),'String', '\fontsize{10} Received Level [dB]');
set(gcf, 'Position', [100 100 800 600])
title(['\fontsize{15}', Site, ' - ', num2str(plotdepth), ' m'],'Position',[0 -1.2])
saveas(Radiance,[fpath_plotSub,'\',Site,'_',num2str(plotdepth),'_RLPolarMap.png'])
disp(['Polar Radial Map saved: ', Site, ', ', num2str(plotdepth), ' m'])

end
end

% if generate_RadialPlots == 1  -- All of this code was moved into the radial loop

% RADIAL PLOTS
% for o = makeRadialPlots(1):makeRadialPlots(2):makeRadialPlots(3)
% [PlotTitle, PlotType, freqVec, freq0, atten, Pos, pressure ] = read_shd([intermedDir, ['\Radial_' num2str(sprintf('%03d', o)) '.shd']]);
% PLslice = squeeze(pressure(1, 1,:,:));
% PL = -20*log10(abs(PLslice));
%     
% [x1,y1] = meshgrid(1:rangeStep:(rangeStep*size(PL,2)),1:depthStep:(depthStep*size(PL,1)));
% [xq1,yq1] = meshgrid(1:(rangeStep*size(PL,2)),1:(depthStep*size(PL,1)));
% zq = interp2(x1,y1, PL,xq1, yq1);
%     
% figure(2000+o)
% RL_rad0 = SL - zq;
% RL_rad0(RL_rad0 < RL_threshold) = NaN;
% ye_olde_whale = pcolor(RL_rad0(:,:)); 
% axis ij
% set(ye_olde_whale, 'EdgeColor','none')
% colormap(jet)
% plotbty([intermedDir, '\Radial_',num2str(sprintf('%03d', o)),'.bty'])
% title([Site,' Radial', num2str(o)])
% colorbar
% saveas(ye_olde_whale,[fpath_plotSub,'\',Site,'_',num2str(o),'_RLRadialMap.png'])
% end
% end

%% Save variables for pDetSim
freqSave = char(freqVec/1000);
save([fpath,'\DetSim_Workspace\',Site,'\',Site,'_',timestamp_currentrun,'_bellhopDetRange.mat'],'rr','nrr','freqSave','hdepth');
