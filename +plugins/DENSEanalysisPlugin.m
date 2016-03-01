classdef DENSEanalysisPlugin < hgsetget &  matlab.mixin.Heterogeneous
    % DENSEanalysisPlugin - Base class for all DENSeanalysis plugins
    %
    %   This is a bare-bones plugin class that provides the API for all
    %   plugins to DENSEanalysis
    %
    %   The required methods are:
    %
    %       run(self, DENSEdata)
    %
    %   This class is an abstract class and must be subclassed in order to
    %   create a custom plugin.

    % This Source Code Form is subject to the terms of the Mozilla Public
    % License, v. 2.0. If a copy of the MPL was not distributed with this
    % file, You can obtain one at http://mozilla.org/MPL/2.0/.
    %
    % Copyright (c) 2016 DENSEanalysis Contributors

    properties
        Name        % Plugin name specified in menus and elsewhere
        Description % Brief, description of the plugin
        Version     % String representing the version
        Author      % Author of the plugin
        Email       % Email of the author
        URL         % Url where the plugin was obtained from
    end

    properties (Hidden)
        hwait       % Handle to the waitbartimer object
        Package     % Package in which the plugin is installed
    end

    properties (Dependent)
        PluginDir   % Directory in which all plugins are stored
        InstallDir  % Directory in which this specific plugin is stored
    end

    events
        Status      % Messaging event carrying a status message payload
    end

    % Get/Set Methods
    methods
        function res = get.PluginDir(~)
            % First figure out where this file is located
            res = fileparts(mfilename('fullpath'));
        end

        function res = get.InstallDir(self)
            res = fileparts(which(class(self)));
        end
    end

    methods
        function self = DENSEanalysisPlugin(varargin)
            % Look to see if there is a plugin.json file
            curdir = fileparts(which(class(self)));
            jsonconfig = fullfile(curdir, 'plugin.json');

            if exist(jsonconfig, 'file')
                varargin = [{loadjson(jsonconfig)}, varargin];
            end

            ip = inputParser();
            ip.KeepUnmatched = true;
            ip.addParamValue('Name', '', @(x)ischar(x) && ~isempty(x));
            ip.addParamValue('Description', '', @ischar);
            ip.addParamValue('Version', '', @ischar);
            ip.addParamValue('Author', '', @ischar);
            ip.addParamValue('Email', '', @ischar);
            ip.addParamValue('URL', '', @ischar);
            ip.addParamValue('Package', '', @ischar);
            ip.parse(varargin{:})
            set(self, ip.Results);
        end

        function setStatus(self, message, varargin)
            % setStatus - Fires a `Status` event with the supplied string
            %
            % USAGE:
            %   obj.setStatus(message)
            %
            % INPUTS:
            %   message:    String, Status string to send out with the
            %               event

            if isempty(varargin); varargin = {'INFO'}; end
            eventData = StatusEvent('', message, varargin{:});
            self.notify('Status', eventData);
        end

        function validate(varargin)
            % validate - Checks whether the plugin can run
            %
            %   If any requirements of the plugin are not met, an error
            %   with a descriptive error message is thrown. This message
            %   can be checked with `isAvailable()`

            return;
        end

        function cleanup(self, varargin)
            % cleanup - Cleanup routine that is run by the plugin manager
            %
            % USAGE:
            %   self.cleanup()

            if ~isempty(self.hwait) && isvalid(self.hwait)
                delete(self.hwait)
            end
        end

        function hwait = waitbar(self, varargin)
            % waitbar - Creates a waitbartimer specific to the plugin
            %
            % USAGE:
            %   hwait = self.waitbar(...)
            %
            % INPUTS:
            %   ...:    Any parameter/value pair accepted by the
            %           waitbartimer. This includes 'String',
            %           'WindowStyle', etc.
            %
            % OUTPUTS:
            %   hwait:  Object, Waitbartimer object that can be used to
            %           start, stop, or modify the waitbartimer object

            if isempty(self.hwait) || ~isvalid(self.hwait)
                hwait = waitbartimer();
                self.hwait = hwait;
            else
                hwait = self.hwait;
            end

            set(hwait, varargin{:})
        end

        function bool = hasUpdate(self)
            % hasUpdate - Determines whether an update is available online
            %
            % USAGE:
            %   bool = self.hasUpdate()
            %
            % OUTPUTS:
            %   bool:   Logical, Indicates whether an update is available
            %           (true) or not (false)

            updater = Updater.create(self);
            bool = updater.updateAvailable();
        end

        function bool = update(self, varargin)
            % update - Performs an in-place update of the plugin
            %
            % USAGE:
            %   bool = self.update(silent)
            %
            % INPUTS:
            %   silent:     Logical, Forces the update to be performed
            %               without prompting the user.
            %
            % OUTPUTS:
            %   success:    Integer, Indicates whether the update was
            %               performed (1), whether the current version
            %               updates should be ignored (-1), or if the
            %               update failed (0).

            % Always force the update without a prompt for plugins
            updater = Updater.create(self);
            [bool, versionNumber] = updater.launch(varargin{:});

            if bool
                filename = fullfile(self.InstallDir, 'plugin.json');
                plugin_info = loadjson(filename);
                plugin_info.version = versionNumber;
                savejson('', plugin_info, filename);
            end
        end
    end

    methods (Sealed)
        function [available, msg] = isAvailable(self, data)
            % isAvailable - Indicates whether the plugin can run
            %
            %   If the plugin can run, this function will return true. If
            %   it cannot, it will return false along with a detailed
            %   message supplying as much information about why it can't
            %   run.
            %
            % USAGE:
            %   [bool, msg] = obj.isAvailable(data)
            %
            % INPUTS:
            %   data:   Data object that would be passed to `run` method
            %
            % OUTPUTS:
            %   bool:   Logical, Indicates whether the plugin can run
            %           (true) or not (false)
            %
            %   msg:    String, Message detailing why the plugin won't be
            %           able to be run

            msg = '';
            available = false;

            try
                self.validate(data)
                available = true;
            catch ME
                msg = ME.message;
            end
        end
    end

    % Abstract methods that must be overloaded by each plugin
    methods (Abstract)
        run(self, data);
    end
end
