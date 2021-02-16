%% ROI TOOL CLASS DEFINITION

% This Source Code Form is subject to the terms of the Mozilla Public
% License, v. 2.0. If a copy of the MPL was not distributed with this
% file, You can obtain one at http://mozilla.org/MPL/2.0/.
%
% Copyright (c) 2016 DENSEanalysis Contributors



%% CLASS DEFINITION
classdef roitool < handle

    % various public properties
    properties (Dependent=true,SetAccess='private')
        Type
        AxesHandles
        cLine
    end

    properties (Dependent=true)
        Visible
        Enable
        ROIIndex
        ROIFrame
    end

    properties
        SequenceIndex = [];
        DENSEIndex = [];
    end

    properties (Dependent=true)
        PositionConstraintFcn
    end

    properties (Hidden)
        hmenu
    end

    % private properties
    properties (SetAccess='private',GetAccess='private')

        type = 'unknown';

        % external objects
        hdata
        hfig
        hax

        ignore

        % internal objects
        hmenuitems
        hcline
        himcline
        himcardiac

        % internal variables
        visible = 'off';
        enable  = 'off';
        roiidx  = [];
        frame   = [];

        % listeners
        hlisten_delete
        hlisten_cline

        % appdata string
        appdata = 'CachedHandleToROITool';

        pcfcn = [];

        contextcache = [];

        redrawenable = false;
        clineenable  = false;

        copybuffer = [];
    end

    events
        Suspend
        Restore
    end

    methods

        % constructor
        function obj = roitool(varargin)
            obj = roitoolFcn(obj,varargin{:});
        end

        function buffer = copy(obj)
            if strcmpi(obj.Enable, 'off'); return; end
            roi = obj.hdata.roi(obj.roiidx);
            buffer = struct( ...
                'Position', {roi.Position(obj.frame,:)}, ...
                'IsClosed', {roi.IsClosed(obj.frame,:)}, ...
                'IsCurved', {roi.IsCurved(obj.frame,:)}, ...
                'IsCorner', {roi.IsCorner(obj.frame,:)});
            obj.copybuffer = buffer;
        end

        function cut(obj)
            if strcmpi(obj.Enable, 'off'); return; end
            % First perform a copy, then remove everything
            buffer = copy(obj);
            obj.cLine.reset( ...
                'ResetUndo', false, ...
                'NumberOfLines', numel(buffer.Position));
        end

        function paste(obj)
            if strcmpi(obj.Enable, 'off'); return; end
            if isempty(obj.copybuffer); return; end
            obj.cLine.reset( ...
                'Position', obj.copybuffer.Position, ...
                'IsClosed', obj.copybuffer.IsClosed, ...
                'IsCurved', obj.copybuffer.IsCurved, ...
                'IsCorner', obj.copybuffer.IsCorner, ...
                'ResetUndo', false);
        end

        % destructor
        function delete(obj)
            deleteFcn(obj);
        end

        function redraw(obj)
            redrawFcn(obj);
        end

        function reset(obj)
            resetFcn(obj);
        end

        function val = get.Type(obj)
            val = obj.type;
        end

        function val = get.AxesHandles(obj)
            val = obj.hax;
        end

        function val = get.cLine(obj)
            val = obj.hcline;
        end

        function val = get.Visible(obj)
            val = obj.visible;
        end

        function val = get.Enable(obj)
            val = obj.enable;
        end

        function val = get.ROIIndex(obj)
            val = obj.roiidx;
        end

        function val = get.ROIFrame(obj)
            val = obj.frame;
        end

        function val = get.PositionConstraintFcn(obj)
            val = obj.pcfcn;
        end

        function set.Visible(obj,val)
            setVisibleFcn(obj,val);
        end

        function set.Enable(obj,val)
            setEnableFcn(obj,val);
        end

        function set.ROIIndex(obj,val)
            setROIIndexFcn(obj,val);
        end

        function set.ROIFrame(obj,val)
            setROIFrameFcn(obj,val);
        end

        function set.SequenceIndex(obj,val)
            obj.SequenceIndex = checkSequenceIndex(obj,val);
            reset(obj);
        end

        function set.DENSEIndex(obj,val)
            obj.DENSEIndex = checkDENSEIndex(obj,val);
        end

%         function createROI(obj)
%             createROIFcn(obj);
%         end

        function set.PositionConstraintFcn(obj,fcn)
            obj.hcline.PositionConstraintFcn = fcn;
            obj.pcfcn = fcn;
        end

        function ignoreAxes(obj,hax)
            ignoreAxesFcn(obj,hax);
        end

    end

end



%% CONSTRUCTOR


function obj = roitoolFcn(obj,hdata,hax)

    % test hdata input
    if ~isa(hdata, 'DENSEdata') || numel(hdata) > 1
        error(sprintf('%s:invalidInput',mfilename),...
            'Function requires valid DENSEdata input');
    end

    % test for valid axes handles
    if ~all(ishghandle(hax, 'axes'))
        error(sprintf('%s:invalidInput',mfilename),...
            'Function requires one or more Axes handles.');
    end

    % ensure single parent figure
    if numel(hax) > 1
        hfig = ancestor(hax,'figure');
        hfig = [hfig{:}];
        if ~all(hfig == hfig(1))
            error(sprintf('%s:invalidInput',mfilename),...
                'All axes mut be from a the same figure.');
        end
        hfig = hfig(1);
    else
        hfig = ancestor(hax,'figure');
    end

    % save to object
    obj.hdata = hdata;
    obj.hax   = hax(:);
    obj.hfig  = hfig;

    obj.ignore = false(size(obj.hax));

    % create context menu
    obj.hmenu = uicontextmenu(...
        'parent',   obj.hfig,...
        'tag',      'ContextROI',...
        'UserData', obj, ...
        'Callback', @(varargin)contextMenuFcn(obj));

    % empty cline object
    obj.hcline = cline;
    obj.hcline.UndoEnable = false;

    % interactive objects
    obj.himcline = arrayfun(@(hax)imcline(obj.hcline,hax),obj.hax,...
        'uniformoutput',0);
    obj.himcardiac = arrayfun(@(hax)imcardiac(obj.hcline,hax),obj.hax,...
        'uniformoutput',0);

    obj.himcline   = [obj.himcline{:}];
    obj.himcardiac = [obj.himcardiac{:}];

    [obj.himcline.ContextOpenClosed] = deal('off');

    [obj.himcline.Enable]   = deal('off');
    [obj.himcardiac.Enable] = deal('off');


    % Deletion listener: when the axes are destroyed,
    % the object is no longer valid and must be destroyed
    obj.hlisten_delete = addlistener_mod(handle(obj.hax), ...
        'ObjectBeingDestroyed',@(varargin)delete(obj));

    % cLINE listener
    obj.hlisten_cline = addlistener(obj.hcline,...
        'NewProperty',@(varargin)updateData(obj));
end



%% DESTRUCTOR
function deleteFcn(obj)

    % objects to delete
    tags = {'hlisten_delete','hlisten_cline',...
        'himcline','himcardiac','hcline','hmenu'};

    % attempt to delete objects
    for ti = 1:numel(tags)
        try
            h = obj.(tags{ti});
            if isempty(h)
                continue;
            else
                tf = false(size(h));
                for k = 1:numel(h)
                    tf(k) = (isobject(h(k)) && isvalid(h(k))) ...
                        || ishandle(h(k));
                end
                delete(h(tf));
            end
        catch
            fprintf('could not delete %s.%s\n',...
                mfilename,tags{ti});
        end
    end

end



%% START & STOP

function startFcn(obj)

    % enable redraw/listener & redraw
    obj.redrawenable = true;
    obj.clineenable  = strcmpi(obj.enable,'on');
    redraw(obj)

    % ensure iptPointerManger is active
    iptPointerManager(obj.hfig,'enable');

end


function stopFcn(obj)

    % stop redraw
    obj.redrawenable = false;
    obj.clineenable  = false;

    % reset all context menus from axes,
    % if currently under object control
    if ~isempty(obj.contextcache)
        set(obj.hax(:),{'UIContextMenu'},obj.contextcache(:));
        obj.contextcache = [];
    end

    % deactivate all graphics
    [obj.himcline.Visible] = deal('off');
    [obj.himcardiac.Visible] = deal('off');

end




%% REDRAW

function redrawFcn(obj)

    % check for redraw enable
    if ~obj.redrawenable, return; end

    % current ROI index & frame
    idx = obj.roiidx;
    fr  = obj.frame;

    % check for valid indices
    if isempty(idx) || isempty(fr)
        return;
    end

    % deactivate all objects
    obj.clineenable = false;
    [obj.himcline.Visible]   = deal('off');
    [obj.himcardiac.Visible] = deal('off');

    % update cLine to new positions
    obj.hcline.reset(...
        'position',     obj.hdata.roi(idx).Position(fr,:),...
        'isclosed',     obj.hdata.roi(idx).IsClosed(fr,:),...
        'iscurved',     obj.hdata.roi(idx).IsCurved(fr,:),...
        'iscorner',     obj.hdata.roi(idx).IsCorner(fr,:));

    % reset position constraint function
    obj.hcline.PositionConstraintFcn = obj.pcfcn;

    ena = {obj.Enable, 'off'};

    ROI = findobj(obj.hdata.roitypes, 'Type', obj.Type);

    % visible flags (imcline/imcardiac)
    if strcmpi(obj.Visible,'off')
        vis = {'off', 'off'};
    elseif any(strcmpi(ROI.Type, {'SA', 'LA'}))
        vis = {'off', 'on'};
        ena = {'off', obj.Enable};
    else
        vis = {'on', 'off'};
    end

    % replicate flags
    N = numel(obj.himcline);

    vis = vis(ones(N,1),:);
    vis(obj.ignore,:) = {'off'};

    ena = ena(ones(N,1),:);
    ena(obj.ignore,:) = {'off'};

    % set flags
    [obj.himcline.Visible]   = deal(vis{:,1});
    [obj.himcline.Enable]    = deal(ena{:,1});
    [obj.himcardiac.Visible] = deal(vis{:,2});
    [obj.himcardiac.Enable]  = deal(ena{:,2});

    % set color
    flag_clr = ~isempty(ROI.Color);

    if flag_clr
        clr = ROI.Color;
        for k = 1:numel(obj.himcline)
            A = obj.himcline(k).Appearance;

            if iscell(clr)
                for m = 1:obj.hcline.NumberOfLines
                    A(m).Color = clr{m};
                    A(m).MarkerFaceColor = clr{m};
                end
            else
                [A.Color] = deal(clr);
                [A.MarkerFaceColor] = deal(clr);
            end

            obj.himcline(k).Appearance = A;
        end
    end


    % update axes context menu
    if strcmpi(obj.Enable,'on')

        % cache current context menu
        if isempty(obj.contextcache)
            h = get(obj.hax,'UIContextMenu');
            if ~iscell(h), h = {h}; end
            obj.contextcache = h;
        end

        % new context menus
        set(obj.hax(~obj.ignore),'UIContextMenu',obj.hmenu);
        set(obj.hax( obj.ignore),'UIContextMenu',[]);

    else

        % return context menu to previous operation
        if isempty(obj.contextcache)
            set(obj.hax,'UIContextMenu',[]);
        else
            set(obj.hax(:),{'UIContextMenu'},obj.contextcache(:));
        end
        obj.contextcache = [];

    end


    % reactivate listener
    obj.clineenable = strcmpi(obj.Enable,'on');


% fprintf('updateLine (%0.4f sec)\n',toc);
end




function playbackFcn(obj)

    % check for enabled redraw
    if ~obj.redrawenable, return; end

    % current ROI index & frame
    idx = obj.roiidx;
    fr  = obj.frame;

    % check for valid indices
    if isempty(idx) || isempty(fr)
        return;
    end

    % cache object states
    cache = struct(...
        'imclineActive',     {{obj.himcline.Visible}},...
        'imcardiacActive',   {{obj.himcardiac.Visible}});

    % deactivate objects
    obj.clineenable = false;
    [obj.himcline.Visible]    = deal('off');
    [obj.himcardiac.Visible]  = deal('off');

    % update cLine to new positions
    obj.hcline.reset(...
        'position',     obj.hdata.roi(idx).Position(fr,:),...
        'isclosed',     obj.hdata.roi(idx).IsClosed(fr,:),...
        'iscurved',     obj.hdata.roi(idx).IsCurved(fr,:),...
        'iscorner',     obj.hdata.roi(idx).IsCorner(fr,:));

    % reset position constraint function
    obj.hcline.PositionConstraintFcn = obj.pcfcn;

    % reactivate objects
    for k = 1:numel(obj.himcline)
        if strcmpi(cache.imclineActive{k},'on')
            obj.himcline(k).Visible = 'on';
        end
        if strcmpi(cache.imcardiacActive{k},'on')
            obj.himcardiac(k).Visible = 'on';
        end
    end

    obj.clineenable = strcmpi(obj.enable,'on');

end



function updateData(obj,data)

    % check if we are saving data...
    if ~obj.clineenable, return; end

    % index/frame
    idx   = obj.roiidx;
    frame = obj.frame;

    % ensure validity
    if isempty(idx) || isempty(frame)
        return;
    end

    % new data from cline
    if nargin < 2
        data = struct(...
            'Position',{obj.hcline.Position},...
            'IsClosed',{obj.hcline.IsClosed},...
            'IsCorner',{obj.hcline.IsCorner},...
            'IsCurved',{obj.hcline.IsCurved});
    end

    % pass to DENSEdata object
    obj.hdata.updateROI(idx,frame,data);

end

function resetFcn(obj)

    obj.Visible = 'off';

%     % disable cline listener
%     obj.hlisten_cline.Enabled = false;
%
%     % context menus
%     if ~isempty(obj.contextcache)
%         set(obj.hax(:),{'UIContextMenu'},obj.contextcache(:));
%     end
%     obj.contextcache = [];
%
%     % disabled/invisible imcline objects
%     for k = 1:numel(obj.himcline)
%         obj.himcline(k).Visible = 'off';
%         obj.himcline(k).Enable  = 'off';
%         obj.himcardiac(k).Visible = 'off';
%         obj.himcardiac(k).Enable  = 'off';
%     end
%     obj.visible = 'off';
%     obj.enable  = 'off';

    % reset cline
    obj.hcline.reset;

    % reset variables
%     obj.pcfcn   = [];
    obj.roiidx  = [];
    obj.frame   = [];
%     obj.ignore(:) = false;

end




%% SET VISIBLE/ENABLE

function setVisibleFcn(obj,val)

    % check new property
    validate_on_off(val, sprintf('%s:invalidVisible', mfilename))

    % determine if enable is allowable
    if strcmpi(val,'on') && isempty(obj.roiidx)
        error(sprintf('%s:invalidVisible',mfilename),'%s',...
            'Cannot make ',mfilename,' visible without valid ROIIndex.');
    end

    % save to object
    obj.visible = val;

    % start/stop object
    if strcmpi(obj.visible,'on')
        startFcn(obj);
    else
        stopFcn(obj);
    end

end







function setEnableFcn(obj,val)
    % check new property
    validate_on_off(val, sprintf('%s:invalidEnable', mfilename))

    % determine if enable is allowable
    if strcmpi(val,'on') && isempty(obj.roiidx)
        error(sprintf('%s:invalidEnable',mfilename),'%s',...
            'Cannot enable ',mfilename,' without valid ROIIndex.');
    end

    % save to object
    obj.enable = val;

    % redraw
    redraw(obj);

end



%% SET ROI INDEX & FRAME

function setROIIndexFcn(obj,ridx)

    % check for empty DENSEdata
    if isempty(obj.hdata)
        error(sprintf('%s:noDENSEdata',mfilename),'%s',...
            'Invalid Sequence Index; no DENSEdata has been loaded.');
    end

    % check roiidx
    rng = [1,numel(obj.hdata.roi)];
    seqidx = obj.SequenceIndex;

    if ~isnumeric(ridx) || ~isscalar(ridx)  || ...
       (ridx < rng(1) || rng(2) < ridx)
        errstr = sprintf('%s [%d,%d]',...
            'Invalid ROIIndex; value must be on the range',rng);
    elseif isempty(seqidx)
        errstr = 'ROIIndex cannot be specified - SequenceIndex is empty.';
    elseif ~any(ridx == obj.hdata.findROI(seqidx))
        errstr = sprintf('%s [%d].',['The ROIIndex does not ',...
            'correspond to the SequenceIndex'],obj.seqidx);
    end

    % throw error
    if exist('errstr','var')
        error(sprintf('%s:invalidROIIndex',mfilename),errstr);
    end

    % save to object
    obj.type   = obj.hdata.roi(ridx).Type;
    obj.roiidx = ridx;
    obj.frame  = 1;

    % update display
    playbackFcn(obj);
%     redraw(obj);

end


function setROIFrameFcn(obj,frame)

    % determine validity of frame set
    if isempty(obj.roiidx)
        error(sprintf('%s:cannotSetFrame',mfilename),...
            'Cannot set ROIFrame without valid ROIIndex.');
    elseif isempty(obj.SequenceIndex)
        error(sprintf('%s:cannotSetFrame',mfilename),...
            'Cannot set ROIFrame without valid SequenceIndex.');
    end

    % number of frames
    seqidx = obj.SequenceIndex;
    Nfr = obj.hdata.seq(seqidx).NumberInSequence;

    % check frame
    rng = [1,Nfr];
    if ~isnumeric(frame) || ~isscalar(frame)  || ...
       (frame < rng(1) || rng(2) < frame)
        error(sprintf('%s:invalidFrame',mfilename),'%s',...
            'Invalid ROIFrame.  Value must be on the ',...
            'range [', num2str(rng,'%d,%d'), '].');
    end

    % save to object
    obj.frame = frame;

    % update cline
    playbackFcn(obj);
%     redraw(obj);

end





function contextMenuFcn(obj)

    % determine current axes
    hax = gco;

    % clear context menu
    %delete(allchild(obj.hmenu));

    roiidx = obj.roiidx;
    frame  = obj.frame;
    seqidx = obj.SequenceIndex;

    if isempty(roiidx) || isempty(frame) || isempty(seqidx)
        return;
    end

    Nfr = obj.hdata.seq(seqidx).NumberInSequence;

    % label string
    type = obj.hdata.roi(roiidx).Type;
    if any(strcmpi(type,{'open','closed'}))
        lbl = 'Contour';
    else
        lbl = 'Region';
    end

    % test
    curempty  = isempty(obj.hdata.roi(roiidx).Position{frame,1});
    prevempty = (frame == 1) || ...
                isempty(obj.hdata.roi(roiidx).Position{frame-1,1});
    nextempty = (frame == Nfr) || ...
                isempty(obj.hdata.roi(roiidx).Position{frame+1,1});

    if isempty(obj.hmenuitems)
        obj.hmenuitems = [ ...
            uimenu(obj.hmenu,'Tag','Delete', ...
                    'Label',['Delete ' lbl], ...
                    'Callback',@(varargin)saveROI());
            uimenu(obj.hmenu,'Tag','Redraw',...
                    'Label',['Redraw ' lbl],...
                    'Callback',@(varargin)drawROI());
            uimenu(obj.hmenu,'Tag','Draw',...
                    'Label',['Draw ' lbl],...
                    'Callback',@(varargin)drawROI());
            uimenu(obj.hmenu,...
                    'Tag',      'CopyPrev',...
                    'Label',    sprintf('Copy Frame %d %s',frame-1,lbl),...
                    'Callback', @(varargin)saveROI(frame-1));
            uimenu(obj.hmenu,...
                    'Tag',      'CopyNext',...
                    'Label',    sprintf('Copy Frame %d %s',frame+1,lbl),...
                    'Callback', @(varargin)saveROI(frame+1))];

        P = (1:numel(obj.hmenuitems)) * 10;
        arrayfun(@(x,y)setappdata(x,'Priority',y), obj.hmenuitems(:), P(:));
    end

    % Sort the menu items
    items = findall(obj.hmenu, 'type', 'uimenu');
    priority = arrayfun(@(x)getappdata(x, 'Priority'), items, 'uni', 0);
    priority(cellfun(@isempty, priority)) = {Inf};
    [~, sortind] = sort([priority{:}], 'descend');
    set(obj.hmenu, 'Children', items(sortind));

    % Figure out which menu items to display or hide
    if ~curempty
        visible = {'Delete', 'Redraw'};
    else
        visible = {'Draw'};
    end

    if ~prevempty
        visible = cat(2, visible, {'CopyPrev'});

        % Update the label as well as the callback
        menuitem = findall(obj.hmenuitems, 'Tag', 'CopyPrev');
        set(menuitem, ...
            'Label',    sprintf('Copy Frame %d %s',frame-1,lbl),...
            'Callback', @(varargin)saveROI(frame-1));
    end

    if ~nextempty
        visible = cat(2, visible, {'CopyNext'});

        menuitem = findall(obj.hmenuitems, 'Tag', 'CopyNext');
        set(menuitem, ...
            'Label',    sprintf('Copy Frame %d %s',frame+1,lbl),...
            'Callback', @(varargin)saveROI(frame+1));
    end

    % Make all invisible
    set(obj.hmenuitems, 'Visible', 'off')
    tags = get(obj.hmenuitems, 'tag');
    set(obj.hmenuitems(ismember(tags, visible)), 'Visible', 'on')

    function drawROI()

        % delete the ROI
        saveROI();

        % notify other objects to suspend operation
        notify(obj,'Suspend');
        cleanupObj = onCleanup(@()notify(obj,'Restore'));

        % Get the ROI that corresponds to the tag
        ROI = findobj(obj.hdata.roitypes, 'Type', obj.Type);

        % Check if this is empty, because that's an issue...
        % TODO: Do some robust handling of this
        if isempty(ROI)
            error(sprintf('%s:InvalidROIType', mfilename), ...
                'Unable to locate this ROI Type.')
        end

        [pos, iscls, iscrv, iscrn] = ROI.drawContour(hax, ...
            'MarkerSize', 10, 'LineWidth', 2);

        % save to DENSEdata object
        saveROI(pos, iscls, iscrv, iscrn);
    end



    function saveROI(varargin)

        % copy values from specified frame
        if nargin == 1
            newframe = varargin{1};
            pos   = obj.hdata.roi(roiidx).Position(newframe,:);
            iscls = obj.hdata.roi(roiidx).IsClosed(newframe,:);
            iscrv = obj.hdata.roi(roiidx).IsCurved(newframe,:);
            iscrn = obj.hdata.roi(roiidx).IsCorner(newframe,:);

        % use inputted value
        elseif nargin == 4
            [pos,iscls,iscrv,iscrn] = deal(varargin{1:4});
%             pos   = varargin{1};
%             iscls = varargin{2};
%             iscrv = varargin{3};
%             iscrn = varargin{4};

        % clear all values, based on Type
        else
            pos   = {zeros(0,2)};
            iscls = {true};
            iscrv = {true};
            iscrn = {false};
            switch lower(obj.Type)
                case 'la',      iscls = {false};
                case 'line',    iscrv = {false};
            end
        end

        data = struct('Position',{pos},'IsClosed',{iscls},...
            'IsCurved',{iscrv},'IsCorner',{iscrn});
        obj.clineenable = true;
        updateData(obj,data);
        obj.clineenable = strcmpi(obj.enable,'on');

        % update display
        playbackFcn(obj)
    end
end





function ignoreAxesFcn(obj,hax)

    if isempty(hax)
        obj.ignore(:) = false;
        return
    end

    % ensure all inputs are axes
    if ~all(ishghandle(hax, 'axes'))
        errstr = 'Function requires Axes handles.';
    elseif ~isempty(setdiff(hax,obj.hax))
        errstr = 'One or more axes is not recognized.';
    end

    if exist('errstr','var')
        error(sprintf('%s:invalidIgnoreAxes',mfilename),errstr);
    end

    % intersection of hax with object
    obj.ignore = ismember(obj.hax,hax);

    % update display
    redraw(obj);

end



function val = checkSequenceIndex(obj,val)

    if isempty(obj.hdata)
        error(sprintf('%s:invalidSequenceIndex',mfilename),...
            'No valid DENSEdata is loaded.')
    end

    % check sequence index
    rng = [1 numel(obj.hdata.seq)];
    if ~isnumeric(val) || ~isscalar(val) || ...
       val < rng(1) || rng(2) < val
        error(sprintf('%s:invalidSequenceIndex',mfilename),...
            'Invalid sequence index.')
    end


end

function val = checkDENSEIndex(obj,val)

    if isempty(obj.hdata)
        error(sprintf('%s:invalidDENSEIndex',mfilename),...
            'No valid DENSEdata is loaded.')
    end

    % check sequence index
    rng = [1 numel(obj.hdata.dns)];
    if ~isnumeric(val) || ~isscalar(val) || ...
       val < rng(1) || rng(2) < val
        error(sprintf('%s:invalidDENSEIndex',mfilename),...
            'Invalid DENSE index.')
    end


end

