function varargout = DENSEanalysis(varargin)
% DENSEANALYSIS M-file for DENSEanalysis.fig
%   DENSEANALYSIS, by itself, creates a new DENSEANALYSIS or
%   raises the existing singleton*.
%
%   H = DENSEANALYSIS returns the handle to a new DENSEANALYSIS or
%   the handle to the existing singleton*.
%
%   DENSEANALYSIS('CALLBACK',hobj,eventData,handles,...) calls the
%   local function named CALLBACK in DENSEANALYSIS.M with the given
%   input arguments.
%
%   DENSEANALYSIS('Property','Value',...) creates a new
%   DENSEANALYSIS or raises the existing singleton*.  Starting from
%   the left, property value pairs are applied to the GUI before
%   DENSEanalysis_OpeningFcn gets called.  An unrecognized property
%   name or invalid value makes property application stop.  All inputs
%   are passed to DENSEanalysis_OpeningFcn via varargin.
%
%   *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%   instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help DENSEanalysis

% This Source Code Form is subject to the terms of the Mozilla Public
% License, v. 2.0. If a copy of the MPL was not distributed with this
% file, You can obtain one at http://mozilla.org/MPL/2.0/.
%
% Copyright (c) 2016 DENSEanalysis Contributors

% Last Modified by GUIDE v2.5 13-May-2013 13:28:30

    % Begin initialization code - DO NOT EDIT
    gui_Singleton = 1;
    gui_State = struct('gui_Name',       mfilename, ...
                       'gui_Singleton',  gui_Singleton, ...
                       'gui_OpeningFcn', @DENSEanalysis_OpeningFcn, ...
                       'gui_OutputFcn',  @DENSEanalysis_OutputFcn, ...
                       'gui_LayoutFcn',  [] , ...
                       'gui_Callback',   []);
    if nargin && ischar(varargin{1})
        gui_State.gui_Callback = str2func(varargin{1});
    end

    if nargout
        [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
    else
        gui_mainfcn(gui_State, varargin{:});
    end
    % End initialization code - DO NOT EDIT
end



%% OPENING FUNCTION
function handles = DENSEanalysis_OpeningFcn(~, ~, handles, varargin)
    if ~isappdata(handles.hfig,'GUIInitializationComplete')
        DENSEsetup;
        handles = initFcn(handles.hfig);
    end

    % update the figure
    setappdata(handles.hfig,'GUIInitializationComplete',true);
    handles = resetFcn(handles.hfig);

    % start pointer manager
    iptPointerManager(handles.hfig,'enable')

    if isfield(handles, 'splash') && ~isempty(handles.splash) && ...
            isvalid(handles.splash)
        delete(handles.splash)
    end
end


%% OUTPUT FUNCTION
% Outputs from this function are returned to the command line.
function varargout = DENSEanalysis_OutputFcn(~, ~, handles)
    varargout{1} = handles;
end



%% DELETION FUNCTION
function hfig_DeleteFcn(~, ~, handles)
    % ensure all objects/listeners are deleted
    tags = {'hlisten_sidebar','hsidebar','hpopup',...
        'hdicom','hdense','hanalysis','hdata'};

    for ti = 1:numel(tags)
        try
            h = handles.(tags{ti});
            if isobject(h)
                if isvalid(h), delete(h); end
            elseif ishandle(h)
                delete(h);
            end
        catch
            fprintf('could not delete handles.%s...\n',tags{ti});
        end
    end
end

%% LOAD/SAVE

function menu_new_Callback(~, ~, handles)
    loadFcn(handles,'dicom');
end

function menu_open_Callback(~, ~, handles)
    loadFcn(handles,'dns');
end

function menu_save_Callback(~, ~, handles)
    saveFcn(handles,false);
end

function menu_saveas_Callback(~, ~, handles)
    saveFcn(handles,true);
end

function tool_new_ClickedCallback(~, ~, handles)
    loadFcn(handles,'dicom');
end

function tool_open_ClickedCallback(~, ~, handles)
    loadFcn(handles,'dns');
end

function tool_save_ClickedCallback(~, ~, handles)
    saveFcn(handles,false);
end

function loadFcn(handles,type, startpath)

    if nargin<3
        % proper startpath
        switch type
            case 'dicom'
                startpath = get(handles.config, 'locations.dicomfolder', userdir());
            otherwise,
                startpath = get(handles.config, 'locations.matpath', userdir());
        end
    end

    % try to load new data
    try
        [uipath,uifile] = load(handles.hdata,type,startpath);
    catch ERR
        uipath = [];
        errstr = ERR.message;
        h = errordlg(errstr,'','modal');
        ERR.getReport()
        waitfor(h);
    end
    if isempty(uipath), return; end

    % save path to figure
    switch type
        case 'dicom',
            set(handles.config, 'locations.dicomfolder', uipath)
            set(handles.config, 'locations.matfile', '')
            f = 'new';
        otherwise,
            set(handles.config, 'locations.matpath', uipath)
            set(handles.config, 'locations.matfile', uifile)
            [~,f,~] = fileparts(uifile);
    end
    guidata(handles.hfig,handles);

    % figure name
    set(handles.hfig,'Name',['DENSEanalysis: ' f]);

    % update figure
    resetFcn(handles.hfig);

end


function windowkeypress(src, evnt)
    if ~isempty(evnt.Modifier)
        modifiers = sort(evnt.Modifier);
        key = strcat(sprintf('%s-', modifiers{:}), evnt.Key);
    else
        key = evnt.Key;
    end

    handles = guidata(src);

    viewer  = getCurrentDataViewer(handles);
    playbar = viewer.hplaybar;

    switch key
        case {'n', 'rightarrow', 'd'}
            if ~isempty(playbar.Value) && ~playbar.IsPlaying
                playbar.Value = mod(playbar.Value, playbar.Max) + 1;
            end
        case {'b', 'leftarrow', 'a'}
            if ~isempty(playbar.Value) && ~playbar.IsPlaying
                playbar.Value = mod((playbar.Value - 2), playbar.Max) + 1;
            end
        case {'control-z', 'command-z'}
            if isa(viewer, 'DENSEviewer') || isa(viewer, 'DICOMviewer')
                cLine = viewer.hroi.cLine;
                if cLine.UndoEnable
                    cLine.undo();
                end
            end
        case {'control-c', 'command-c'}
            if isa(viewer, 'DENSEviewer') || isa(viewer, 'DICOMviewer')
                viewer.hroi.copy();
            end
        case {'control-x', 'command-x'}
            if isa(viewer, 'DENSEviewer') || isa(viewer, 'DICOMviewer')
                viewer.hroi.cut();
            end
        case {'control-v', 'command-v'}
            if isa(viewer, 'DENSEviewer') || isa(viewer, 'DICOMviewer')
                viewer.hroi.paste();
            end
        case 'equal'
            ax = get(handles.hfig, 'CurrentAxes');
            zoom(ax, 2);
        case 'hyphen'
            ax = get(handles.hfig, 'CurrentAxes');
            zoom(ax, 0.5);
        case 'e'
            if strcmpi(get(handles.tool_roi, 'state'), 'on')
                set(handles.tool_roi, 'State', 'off')
            else
                set(handles.tool_roi, 'State', 'on')
            end
            cb = get(handles.tool_roi, 'ClickedCallback');
            feval(cb, handles.tool_roi, []);
        case 'space'

            if isempty(playbar.Value)
                return
            end

            if playbar.IsPlaying
                playbar.stop()
            else
                playbar.play()
            end
    end
end

function saveFcn(handles,flag_saveas)
    defaultpath = get(handles.config, 'locations.matpath', '');
    defaultfile = get(handles.config, 'locations.matfile', '');
    file = save(handles.hdata, defaultpath, defaultfile, flag_saveas);
    if ~isempty(file)
        [p,f,e] = fileparts(file);
        set(handles.config, 'locations.matpath', p);
        set(handles.config, 'locations.matfile', [f, e]);
        set(handles.hfig, 'Name', ['DENSEanalysis: ' f]);
    end
end



%% INITIALIZE GUI
function handles = initFcn(hfig)
% The majority of the operations here are concerned with the creation of
% support objects (tabs, playbars, images, etc.) and the setting of
% permanent display parameters (colors, axes properties, listeners).

    thisdir = fileparts(mfilename('fullpath'));

    splash = SplashScreen( ...
        'Icon', fullfile(thisdir, 'images', 'splash.png'), ...
        'Size', [500 325], ...
        'BackgroundColor', [0 0 0], ...
        'ForegroundColor', [1 1 1], ...
        'Status', 'Loading...');

    status = @(msg)set(splash, 'Status', msg);

    clnup = onCleanup(@()delete(splash(isvalid(splash))));
    setappdata(hfig,'SplashScreen',clnup)

    % report
    status('Initializing software...');

    % set some appdata
    setappdata(hfig,'GUIInitializationComplete',false);
    setappdata(hfig,'WorkspaceLoaded',false);

    % gather guidata
    handles = guidata(hfig);
    %guidata(hfig, handles);

    % Bind all keyboard events
    set(handles.hfig, 'WindowKeyPressFcn', @windowkeypress)

    accelerators = struct(...
        'menu_save',        'S', ...
        'menu_about',       '/', ...
        'menu_analysisopt', '.', ...
        'menu_new',         'N', ...
        'menu_open',        'O', ...
        'menu_exportmat',   'M', ...
        'menu_runanalysis', 'R');

    func = @(x,y)set(findobj(handles.hfig, 'tag', x), 'Accelerator', y);
    cellfun(func, fieldnames(accelerators), struct2cell(accelerators));

    % LOAD GUI DATA FROM FILE----------------------------------------------
    % Here, we attempt to locate and load saved GUI variables from a known
    % file.  Note if this doesn't work, we ensure that the variables
    % contain some default information.

    status('Loading configurations...')

    % Initialize configuration object
    folder = fullfile(userdir(), '.denseanalysis');
    exists = exist(folder, 'file');

    % This is just a file lingering around
    if exists ~= 7;
        if exists; delete(folder); end
        mkdir(folder)
    end

    filename = fullfile(folder, [mfilename, '.json']);
    handles.config = Configuration(filename);

    % CREATE DENSE DATA OBJECT---------------------------------------------
    hdata = DENSEdata;

    status('Initializing GUI...');

    % Add the basic ROI types
    addROIType(hdata, rois.CurvedRegion)
    addROIType(hdata, rois.PolylineRegion)
    addROIType(hdata, rois.LVShortAxis)
    addROIType(hdata, rois.LVLongAxis)
    addROIType(hdata, rois.ClosedContour)
    addROIType(hdata, rois.OpenContour)

    dicom_hpanel = uipanel(...
        'parent',handles.hfig,...
        'BorderType','none',...
        'BackgroundColor',get(hfig,'color'));
    hdicom = DICOMviewer(hdata,...
        dicom_hpanel,handles.popup_dicom);

    dense_hpanel = uipanel(...
        'parent',handles.hfig,...
        'BorderType','none',...
        'BackgroundColor',[0 0 0]);
    hdense = DENSEviewer(hdata,...
        dense_hpanel,handles.popup_dense);

    % Enable undo functionality
    hdense.hroi.cLine.UndoEnable = true;

    analysis_hpanel = uipanel(...
        'parent',handles.hfig,...
        'BorderType','none',...
        'BackgroundColor',[0 0 0]);
    hanalysis = AnalysisViewer(hdata,...
        analysis_hpanel,handles.popup_analysis);

    hslice = SliceViewer(hdata,handles.popup_slice);
    harial = ArialViewer(hdata,handles.popup_arial);

    % Turn off all listeners
    items = {hdense, hdicom, hanalysis, hslice, harial};
    cellfun(@(x)x.disable('redraw'), items);

    % CREATE TAB OBJECTS---------------------------------------------------

    % initialize the SIDETABS object
    hsidebar = sidetabs(handles.hfig);
    hsidebar.addTab({'DICOM','data'},dicom_hpanel);
    set(dicom_hpanel, 'UserData', hdicom);
    hsidebar.addTab({'DENSE','data'},dense_hpanel);
    set(dense_hpanel, 'UserData', hdense);
    hsidebar.addTab({'DENSE','analysis'},analysis_hpanel);
    set(analysis_hpanel, 'UserData', hanalysis);
    hsidebar.TabWidth  = 40;
    hsidebar.TabHeight = 70;

    % initialize POPUPTABS object
    hpopup = popuptabs(handles.hfig);
    hpopup.addTab('DICOM controls',handles.popup_dicom);
    hpopup.addTab('DENSE controls',handles.popup_dense);
    hpopup.addTab('Arial View',handles.popup_arial);
    hpopup.addTab('Slice View',handles.popup_slice);
    hpopup.addTab('Analysis controls',handles.popup_analysis);
    hpopup.TabWidth = 200;
    hpopup.TabHeight = 20;

    % determine sidetabs/popuptabs position options
    pos = getpixelposition(hpopup);
    hsidebar.DistanceToPanel = pos(3);
    hpopup.LeftOffset = hsidebar.Width;


    % initialize SIDETABS listener
    hlisten_sidebar = addlistener(hsidebar,...
        'SwitchTab',@(varargin)switchstate(handles.hfig));

    % ZOOM/PAN/ROTATE BEHAVIOR---------------------------------------------

    % zoom/pan/rotate objects
    hzoom = zoom(handles.hfig);
    hpan  = pan(handles.hfig);
    hrot  = rotate3d(handles.hfig);

    % contrast tool
    hcontrast = contrasttool.cached(handles.hfig);
    hcontrast.addToggle(handles.htoolbar);
    hchild = get(handles.htoolbar,'children');
    set(handles.htoolbar,'children',hchild([2:3 1 4:end]));


    % default renderers
    if ishg2()
        handles.renderer = repmat({'opengl'},[3 1]);
    else
        handles.renderer = repmat({'painters'},[3 1]);
    end

    handles.LastTab = 1;

    % CLEANUP--------------------------------------------------------------

    % save new objects to figure
    handles.hdata               = hdata;
    handles.hsidebar            = hsidebar;
    handles.hlisten_sidebar     = hlisten_sidebar;
    handles.hpopup              = hpopup;
    handles.dicom_hpanel        = dicom_hpanel;
    handles.hdicom              = hdicom;
    handles.dense_hpanel        = dense_hpanel;
    handles.hdense              = hdense;
    handles.analysis_hpanel     = analysis_hpanel;
    handles.hanalysis           = hanalysis;
    handles.hslice              = hslice;
    handles.harial              = harial;
    handles.hzoom               = hzoom;
    handles.hpan                = hpan;
    handles.hrot                = hrot;
    handles.hcontrast           = hcontrast;
    handles.splash              = splash;

    % some of the toolbar items have strange tags, so lets gather 'em up.
    handles.htools = allchild(handles.htoolbar);

    % link some menu enable to tool enable
    hlink = linkprop([handles.tool_new,handles.menu_new],'Enable');
    setappdata(handles.tool_new,'linkMenuToolEnable',hlink);
    hlink = linkprop([handles.tool_open,handles.menu_open],'Enable');
    setappdata(handles.tool_open,'linkMenuToolEnable',hlink);
    hlink = linkprop([handles.tool_save,...
        handles.menu_save,handles.menu_saveas],'Enable');
    setappdata(handles.tool_save,'linkMenuToolEnable',hlink);

    % Go ahead and store GUIDATA so that plugins can access it as needed
    guidata(handles.hfig, handles);

    % Load plugins
    base = 'plugins.DENSEanalysisPlugin';
    handles.hmanager = plugins.PluginManager(base, hdata);

    guidata(handles.hfig, handles);

    handles.hpluginmenu = plugins.PluginMenu(handles.hmanager, hfig);

    % save all data to the figure
    guidata(handles.hfig,handles);

    set(handles.hfig, 'ResizeFcn', @(s,e)resizeFcn(s));

    config = handles.config;

    % Make sure that we have an updater field in the configuration
    if ~isfield(config, 'updater')
        config.updater = structobj();
    end

    % If auto updates are disabled
    if getfieldr(config.updater, 'auto', true)
        status('Checking for updates...')
        checkForUpdate(handles);
    end

    movegui(handles.hfig, 'center')
    drawnow

    status('Reticulating splines...'); pause(0.2);

    % Add a menu item that allows us to check for updates manually and also
    % a toggle for turning automatic update off / on
    hmenu = get(findall(handles.hfig, 'tag', 'menu_about'), 'Parent');

    handles.hautoupdate = uimenu('Parent', hmenu, ...
                                 'Label', 'Automatically Check for Updates', ...
                                 'Callback', @(s,e)toggleAutoUpdate(handles));

    handles.hupdateCheck = uimenu('Parent', hmenu, ...
                                  'Label', 'Check for Updates', ...
                                  'Callback', @(s,e)checkForUpdate(handles, 1));

    % Add a callback to this menu to fix the toggle
    set(hmenu, 'Callback', @(s,e)refreshAutoUpdateMenu(handles));
end

function refreshAutoUpdateMenu(handles)
    if getfieldr(handles.config.updater, 'auto', true)
        set(handles.hautoupdate, 'checked', 'on')
    else
        set(handles.hautoupdate, 'checked', 'off')
    end
end

function toggleAutoUpdate(handles)
    status = getfieldr(handles.config.updater, 'auto', true);
    handles.config.updater.auto = ~status;
end

function checkForUpdate(handles, force)

    % Force a check despite the time of the last check
    if ~exist('force', 'var')
        force = false;
    end

    config = handles.config;

    % If automatic updates are enabled, go ahead and check for them.
    thisdir = fileparts(mfilename('fullpath'));
    info = loadjson(fullfile(thisdir, 'info.json'));

    u = Updater.create(info, 'Config', config.updater, ...
                             'InstallDir', thisdir);

    % If it hasn't been at least this 15 minutes since the last check, skip
    lastcheck = getfieldr(config.updater, 'lastcheck', 0);
    maxCheckInterval = [0 0 0 0 15 Inf];
    if ~any(datevec(now - lastcheck) > maxCheckInterval) && ~force
        return;
    end

    % Record the time that we check for an update
    config.updater.lastcheck = now;

    % Check if the user wants to perform the update.  If the user
    % previously selected to ignore a specific version, we use THAT version
    % as the reference at this point so that only new version trigger an
    % update.
    refVersion = getfieldr(config.updater, 'ignoreVersion', u.Version);

    try
        [doupdate, version] = u.launch(false, refVersion);

        if doupdate == -1
            % User doesn't want any more updates for this version
            config.updater.ignoreVersion = version;
        elseif doupdate == 1
            % User applied the update successfully so we want to update the
            % version number that we saved.
            config.updater.version = version;
        end
    catch ME
        % If the update was not done through the menu option, just print
        % the status out.
        if isempty(gcbo)
            fprintf('Unable to fetch updates. %s\n', ME.message);
        % Otherwise provide an error dialog with more information
        else
            errordlg({'Unable to fetch updates.'; ME.message});
        end
    end
end

function resizeFcn(hfig)
    h = guidata(hfig);

    h.hsidebar.redraw();
    h.hpopup.redraw();

    % Redraw only the visible tab because the others will automatically
    % redraw when the tab is changed
    objs = {h.hdicom, h.hdense, h.hanalysis};
    if h.hsidebar.ActiveTab <= numel(objs)
        objs{h.hsidebar.ActiveTab}.redraw();
    end
end


%% RESET GUI
function handles = resetFcn(hfig)
% this function ensures the state of the GUI matches the data loaded into
% the DENSEdata object (handles.hdata)

    % gather gui data
    handles = guidata(hfig);

    % disable zoom/pan/rot
    handles.hzoom.Enable = 'off';
    handles.hpan.Enable  = 'off';
    handles.hrot.Enable  = 'off';

    % reset tabs to initial state
    handles.hsidebar.ActiveTab      = 1;

    handles.hsidebar.Enable();

    inds = handles.hsidebar.find([handles.dense_hpanel,handles.analysis_hpanel]);
    handles.hsidebar.Enable(inds)   = {'off'};

    H = [handles.popup_dicom, handles.popup_dense, handles.popup_arial, ...
         handles.popup_slice, handles.popup_analysis];
    inds = handles.hpopup.find(H);

    handles.hpopup.Visible(:) = {'off'};
    handles.hpopup.Visible(inds) = {'on'};
    handles.hpopup.Enable(:) = {'off'};

    % reset renderer
    handles.renderer(:) = {'painters'};
    handles.LastTab = 1;

    % disable toolbar tools
    set(handles.htools,'Enable','off');
    wild = {'*open','*new'};
    tf = cellfun(@(tag)any(strwcmpi(tag,wild)),get(handles.htools,'tag'));
    set(handles.htools(tf),'Enable','on');


    % quit if no data to display
    if numel(handles.hdata.seq) == 0
        handles.hsidebar.redraw();
        handles.hpopup.redraw();
        return
    end

    % enable/open popups
    handles.hpopup.Enable(inds) = {'on'};
    handles.hpopup.IsOpen(inds) = 1;

    % enable sidetabs
    inds = handles.hsidebar.find([handles.dense_hpanel,handles.analysis_hpanel]);
    handles.hsidebar.Enable(inds) = {'on'};

    % activate/deactivate stuff
    switchstate(handles.hfig)

    % trigger resize functions
    % (panels are resized via "hsidebar" object)
    handles.hsidebar.redraw();
    handles.hpopup.redraw();
end


%% SWITCH TAB (DICOM/DENSE/ANALYSIS)
function switchstate(hfig)
    handles = guidata(hfig);

    % Get the indices of the sidebar tabs
    sidebarinds = handles.hsidebar.find([
        handles.dicom_hpanel
        handles.dense_hpanel
        handles.analysis_hpanel]);

    % current tab
    tabidx = handles.hsidebar.ActiveTab;
    handles.renderer{handles.LastTab} = get(handles.hfig, 'renderer');

    if ~ismember(tabidx, sidebarinds)
        return
    end

    set(handles.hfig, 'Colormap', gray)

    wild = {'*zoom*','*pan','*rotate*','tool*','*save*','*contrast*'};
    tf = cellfun(@(tag)any(strwcmpi(tag,wild)),get(handles.htools,'tag'));
    set(handles.htools(tf),'Enable','on');

    handles.hdicom.ROIEdit = 'off';
    handles.hdense.ROIEdit = 'off';
    set(handles.tool_roi,'State','off','enable','on');

    popupinds = handles.hpopup.find([
        handles.popup_dicom
        handles.popup_arial
        handles.popup_dense
        handles.popup_slice
        handles.popup_analysis
    ]);

    switch tabidx

        case 1

            tf = logical([1 0 1 1 0]);
            handles.hpopup.Visible(popupinds(tf))  = {'on'};
            handles.hpopup.Visible(popupinds(~tf)) = {'off'};

            handles.hanalysis.Enable = 'off';

            % transfer slice/arial to DICOM viewer
            handles.hdense.SliceViewer = [];
            handles.hdense.ArialViewer = [];
            handles.hdicom.SliceViewer = handles.hslice;
            handles.hdicom.ArialViewer = handles.harial;
            redraw(handles.hdicom);

        case 2
            tf = logical([0 1 1 1 0]);
            handles.hpopup.Visible(popupinds(tf))  = {'on'};
            handles.hpopup.Visible(popupinds(~tf)) = {'off'};

            handles.hanalysis.Enable = 'off';

            % transfer slice/arial to DENSE viewer
            handles.hdicom.SliceViewer = [];
            handles.hdicom.ArialViewer = [];
            handles.hdense.SliceViewer = handles.hslice;
            handles.hdense.ArialViewer = handles.harial;

            redraw(handles.hdense);

        case 3

            tf = logical([0 0 0 0 1]);
            handles.hpopup.Visible(popupinds(tf))  = {'on'};
            handles.hpopup.Visible(popupinds(~tf)) = {'off'};
            handles.hanalysis.Enable = 'on';
            set(handles.tool_roi,'enable','off');
            redraw(handles.hanalysis);

    end


    set(handles.hfig,'renderer',handles.renderer{tabidx});
    handles.LastTab = tabidx;
    guidata(hfig,handles);

end

function h = getCurrentDataViewer(handles)
    % getCurrentDataViewer - Returns a handle to the current DataViewer
    h = get(handles.hsidebar.CurrentPanel, 'UserData');

    if ~isa(h, 'DataViewer')
        h = [];
    end
end



%% ROI TOOL CALLBACK
function tool_roi_ClickedCallback(~, ~, handles) %#ok<*DEFNU>
% hObject    handle to tool_roi (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

    state = get(handles.tool_roi,'State');

    viewer = getCurrentDataViewer(handles);
    if isprop(viewer, 'ROIEdit')
        viewer.ROIEdit = state;
    end
end


%% MENU: EXPORT UIMENU SELECT
function menu_export_Callback(~, ~, handles)

    h = getCurrentDataViewer(handles);

    if isempty(h)
        return
    end

    imgen = h.isAllowExportImage;
    viden = h.isAllowExportVideo;

    funcs = methods(h);

    exlen = ismember('exportExcel', funcs) && h.isAllowExportExcel;
    maten = ismember('exportMat', funcs) && h.isAllowExportMat;

    if h == handles.hdense
        roien = isAllowExportROI(handles.hdata,h.ROIIndex);
    else
        roien = false;
    end

    strs  = {'off','on'};
    imgen = strs{imgen+1};
    viden = strs{viden+1};
    maten = strs{maten+1};
    exlen = strs{exlen+1};
    roien = strs{roien+1};


    set(handles.menu_exportimage,'enable',imgen);
    set(handles.menu_exportvideo,'enable',viden);
    set(handles.menu_exportmat,  'enable',maten);
    set(handles.menu_exportexcel,'enable',exlen);
    set(handles.menu_exportroi,  'enable',roien);

end


%% MENU: EXPORT IMAGE/VIDEO
function menu_exportimage_Callback(~, ~, handles)
    h = getCurrentDataViewer(handles);

    if isempty(h)
        return
    end

    exportpath = get(handles.config, 'export.image.location', '');

    file = h.exportImage(exportpath);
    if isempty(file), return; end

    handles.config.export.image.location = fileparts(file);
end

function menu_exportvideo_Callback(~, ~, handles)
    h = getCurrentDataViewer(handles);

    if isempty(h)
        return;
    end

    exportpath = get(handles.config, 'export.video.location', '');

    file = h.exportVideo(exportpath);
    if isempty(file), return; end

    handles.config.export.video.location = fileparts(file);
end


%% MENU: EXPORT MAT/EXCEL/ROI
function menu_exportmat_Callback(~, ~, handles, custom_location, default_frame)

    if exist('custom_location', 'var')
        exportpath = custom_location;
        preset_flag = 1;
    else
        exportpath = get(handles.config, 'export.mat.location', '');
        preset_flag = 0;
    end

    if ~exist('default_frame', 'var')
        default_frame = 1;
    end

    h = getCurrentDataViewer(handles);

    if isempty(h)
        return;
    end

    file = h.exportMat(exportpath, preset_flag, default_frame);
    if isempty(file)
        return;
    end

    handles.config.export.mat.location = fileparts(file);
end

function menu_exportexcel_Callback(~, ~, handles, custom_location, default_frame)

    if exist('custom_location', 'var')
        exportpath = custom_location;
        preset_flag = 1;
    else
        exportpath = get(handles.config, 'export.excel.location', '');
        preset_flag = 0;
    end

    h = getCurrentDataViewer(handles);

    if isempty(h)
        return;
    end

    file = h.exportExcel(exportpath, preset_flag, default_frame);
    if isempty(file), return; end

    handles.config.export.excel.location = fileparts(file);
end

function menu_exportroi_Callback(~, ~, handles)
    exportpath = get(handles.config, 'export.roi.location', '');
    uipath = handles.hdense.exportROI(exportpath);
    if isempty(uipath), return; end

    handles.config.export.roi.location = uipath;
end


%% MENU: ANALYSIS UIMENU SELECT
function menu_analysis_Callback(~, ~, handles)
    enable = 'off';

    if handles.hsidebar.ActiveTab == 2
        didx  = handles.hdense.DENSEIndex;
        ridx  = handles.hdense.ROIIndex;
        frame = handles.hdense.frame;
        if handles.hdata.isAllowAnalysis(didx,ridx,frame)
            enable = 'on';
        end
    end
    set(handles.menu_runanalysis,'enable',enable)

end


%% MENU: RUN ANALYSIS
function menu_runanalysis_Callback(~, ~, handles, didx, ridx, frame, varargin)

    % First check to make sure that we've already accepted the RUO
    % statement
    if ~getfieldr(handles.config, 'AcceptedRUO', false)
        accept = ruodialog();

        % Don't allow analysis to run until this is accepted
        if ~accept; return; end

        handles.config.AcceptedRUO = accept;
    end

    if nargin<4
        ridx = handles.hdense.ROIIndex;
        frame = handles.hdense.Frame;
        didx = handles.hdense.DENSEIndex;
    elseif ~exist('didx', 'var')
        didx = 0;
    end

    spdata = handles.hdata.analysis(didx,ridx,frame,varargin{:});
    if isempty(spdata), return; end
    handles.hsidebar.ActiveTab = 3;
end


%% MENU: ANALYSIS DISPLAY OPTIONS
function menu_analysisopt_Callback(~, ~, handles)
    handles.hanalysis.strainoptions;
end


%% MENU: ABOUT THE PROGRAM
function menu_about_Callback(varargin)

    screenpos = get(0,'screensize');
    sz = [400 400];
    pos = [(screenpos(3:4)-sz)/2,sz];

    figure('windowstyle','modal','resize','off',...
        'position',pos,'Name','About DENSEanalysis','NumberTitle','off');
    I = imread('DENSEabout.png');
    imshow(I,[],'init','fit');
    set(gca,'units','normalized','position',[0 0 1 1]);

end


%% MENU: TEST FUNCTION
function menu_test_Callback(varargin)
end
