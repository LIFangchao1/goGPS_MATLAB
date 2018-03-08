%   CLASS Command Interpreter
% =========================================================================
%
% DESCRIPTION
%   Interpreter of goGPS command instructions
%
% EXAMPLE
%   cmd = Command_Interpreter.getInstance();
%
% FOR A LIST OF CONSTANTs and METHODS use doc Command_Interpreter


%--------------------------------------------------------------------------
%               ___ ___ ___
%     __ _ ___ / __| _ | __
%    / _` / _ \ (_ |  _|__ \
%    \__, \___/\___|_| |___/
%    |___/                    v 0.6.0 alpha 2 - nightly
%
%--------------------------------------------------------------------------
%  Copyright (C) 2009-2017 Mirko Reguzzoni, Eugenio Realini
%  Written by:       Gatti Andrea
%  Contributors:     Gatti Andrea, ...
%  A list of all the historical goGPS contributors is in CREDITS.nfo
%--------------------------------------------------------------------------
%
%    This program is free software: you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version.
%
%    This program is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%    along with this program.  If not, see <http://www.gnu.org/licenses/>.
%
%--------------------------------------------------------------------------
% 01100111 01101111 01000111 01010000 01010011
%--------------------------------------------------------------------------

classdef Command_Interpreter < handle    
    
    %% PROPERTIES CONSTANTS
    % ==================================================================================================================================================
    properties (Constant, GetAccess = private)
        OK       = 0;   % No errors
        ERR_UNK  = 1;   % Command unknown
        ERR_NEI  = 2;   % Not Enough Input Parameters
        WRN_TMI  = -3;  % Too Many Inputs
        
        STR_ERR = {'Commad unknown', ...
            'Not enough input parameters', ...
            'Too many input parameters'};
    end
    %
    %% PROPERTIES COMMAND CONSTANTS
    % ==================================================================================================================================================
    properties (GetAccess = public, SetAccess = private)
        % List of the supported commands
        
        CMD_PREPRO      % Pre-processing command
        CMD_CODEPP      % Code point positioning
        CMD_PPP         % Precise point positioning        
        CMD_SEID        % SEID processing (synthesise L2)
        CMD_KEEP        % Function to keep just some observations into receivers (e.g. rate => constellation)
        CMD_SYNC        % Syncronization among multiple receivers (same rate)
        
        PAR_RATE        % Parameter select rate
        PAR_SS          % Parameter select constellation
        PAR_SYNC        % Parameter sync 
        
        CMD_LIST = {'PREPRO', 'CODEPP', 'PPP', 'SEID', 'KEEP', 'SYNC'};
        VALID_CMD = {};
        CMD_ID = [];
        % Struct containing cells are not created properly as constant => see init method
    end
    %
    %% PROPERTIES SINGLETON POINTERS
    % ==================================================================================================================================================
    properties % Utility Pointers to Singletons
        log
    end
    %
    %% PROPERTIES RECEIVERS
    % ==================================================================================================================================================
    properties % Utility Pointers to Singletons
        rec     % List of all the receiver used in a session
        
        trg     % temporary pointer to all the targets
        ref     % temporary pointer to all the reference stations (SEID)
        mst     % temporary pointer to all the master stations
    end
    %
    %% METHOD CREATOR
    % ==================================================================================================================================================
    methods (Static, Access = public)
        % Concrete implementation.  See Singleton superclass.
        function this = Command_Interpreter()
            % Core object creator
            this.log = Logger.getInstance();
            this.init();
        end
    end
    %
    %% METHOD INTERFACE
    % ==================================================================================================================================================
    methods (Static, Access = public)
        function this = getInstance()
            % Get the persistent instance of the class
            persistent unique_instance_cmdi__
            unique_instance_cmdi__ = [];
            
            if isempty(unique_instance_cmdi__)
                this = Command_Interpreter();
                unique_instance_cmdi__ = this;
            else
                this = unique_instance_cmdi__;
                this.init();
            end
        end
    end
    %
    %% METHODS INIT
    % ==================================================================================================================================================
    methods
        function init(this)
            % Define and fill the "CONSTANT" structures of the class
            % Due to MATLAB limits it is not possible to create cells into struct on declaration
            %
            % SYNTAX:
            %   this.init()
            
            % definition of parameters (ToDo: these should be converted into objects)
            % in the definition the character "$" indicate the parameter value
            this.PAR_RATE.name = 'rate';
            this.PAR_RATE.descr = 'processing rate in seconds';
            this.PAR_RATE.par = '(\@)|(\-r\=)|(\-\-rate\=)'; % (regexp) parameter prefix: @ | -r= | --rate= 
            this.PAR_RATE.class = 'double';
            this.PAR_RATE.limits = [0.000001 900];
            this.PAR_RATE.accepted_values = [];
            
            this.PAR_SS.name = 'constellation';
            this.PAR_SS.descr = 'active constellations';
            this.PAR_SS.par = '(\-s\=)|(\-\-constellation\=)'; % (regexp) parameter prefix: -s --constellation
            this.PAR_SS.class = 'char';
            this.PAR_SS.limits = [];
            this.PAR_SS.accepted_values = [];
            
            this.PAR_SYNC.name = 'sync results';
            this.PAR_SYNC.descr = 'use syncronized time only';
            this.PAR_SYNC.par = {'--sync'};
            this.PAR_SYNC.class = '';
            this.PAR_SYNC.limits = [];
            this.PAR_SYNC.accepted_values = [];
            
            % definition of commands
            
            this.CMD_PREPRO.name = {'PREPRO', 'pre_processing'};
            this.CMD_PREPRO.descr = 'code positioning, computation of satellite positions and various corrections';
            this.CMD_PREPRO.rec = {'T'};
            this.CMD_PREPRO.par = [];
            
            this.CMD_CODEPP.name = {'CODEPP', 'ls_code_point_positioning'};
            this.CMD_PREPRO.descr = 'code positioning';
            this.CMD_CODEPP.rec = {'T'};
            this.CMD_CODEPP.par = [this.PAR_RATE this.PAR_SS];
            
            this.CMD_PPP.name = {'PPP', 'precise_point_positioning'};
            this.CMD_PREPRO.descr = 'Precise Point Positioning using carrier phase observations';
            this.CMD_PPP.rec = {'T'};
            this.CMD_PPP.par = [this.PAR_RATE this.PAR_SS this.PAR_SYNC];
            
            this.CMD_SEID.name = {'SEID', 'synthesise_L2'};
            this.CMD_PREPRO.descr = 'generate a Synthesised L2 on a target receiver using n (dual frequencies) reference stations';
            this.CMD_SEID.rec = {'R', 'T'};
            this.CMD_SEID.par = [];
            
            this.CMD_KEEP.name = {'KEEP'};
            this.CMD_PREPRO.descr = 'keep in the object the data of a certain constallation / at a certain rate';
            this.CMD_KEEP.rec = {'T'};
            this.CMD_KEEP.par = [this.PAR_RATE this.PAR_SS];
            
            this.CMD_SYNC.name = {'SYNC'};
            this.CMD_PREPRO.descr = 'syncronize all the receivers at the same rate (with the minimal data span)';
            this.CMD_SYNC.rec = {'T'};
            this.CMD_SYNC.par = [this.PAR_RATE];
            
            % When adding a command remember to add it to the valid_cmd list
            % Create the launcher exec function
            % and modify the method exec to allow execution
            this.VALID_CMD = {};
            this.CMD_ID = [];
            for c = 1 : numel(this.CMD_LIST)
                this.VALID_CMD = [this.VALID_CMD(:); this.(sprintf('CMD_%s', this.CMD_LIST{c})).name(:)];
                this.CMD_ID = [this.CMD_ID, c * ones(size(this.(sprintf('CMD_%s', this.CMD_LIST{c})).name))];
            end
        end
    end
    %
    %% METHODS EXECUTE
    % ==================================================================================================================================================
    % methods to execute a set of goGPS Commands
    methods        
        function exec(this, rec, cmd_list)
            % run a set of commands (divided in cells of cmd_list)
            %
            % SYNTAX:
            %   this.exec(rec, cmd_list)
            if nargin == 2
                state = Global_Configuration.getCurrentSettings();
                cmd_list = state.getCommandList();
            end
            if ~iscell(cmd_list)
                cmd_list = {cmd_list};
            end
            cmd_list = this.fastCheck(cmd_list);
            
            % run each line
            for l = 1 : numel(cmd_list)
                tok = regexp(cmd_list{l},'[^ ]*', 'match'); % get command tokens
                this.log.newLine();
                this.log.addMarkedMessage(sprintf('Executing: %s', cmd_list{l}));
                this.log.starSeparator();
                this.log.newLine();
                
                switch upper(tok{1})
                    case this.CMD_PREPRO.name
                        this.runPrePro(rec, tok(2:end));
                    case this.CMD_CODEPP.name
                        this.runCodePP(rec, tok(2:end));                        
                    case this.CMD_PPP.name
                        this.runPPP(rec, tok(2:end));
                    case this.CMD_SEID.name
                        this.runSEID(rec, tok(2:end));
                    case this.CMD_KEEP.name
                        this.runKeep(rec, tok(2:end));
                    case this.CMD_SYNC.name
                end
            end
        end
        
        % --------------------------------------------------------------------
    end
    %
    %% METHODS EXECUTE (PRIVATE)
    % ==================================================================================================================================================
    % methods to execute a set of goGPS Commands
    methods (Access = private)    
        
        function runPrePro(this, rec, tok)
            % Execute Pre processing
            %
            % INPUT
            %   rec     list of rec objects
            %   tok     list of tokens(parameters) from command line (cell array)
            %
            % SYNTAX
            %   this.runPrePro(rec, tok)
            
            
            [id_trg, found] = this.getMatchingRec(rec, tok, 'T');
            if ~found
                this.log.addWarning('No target found -> nothing to do');
            else
                for r = id_trg
                    this.log.addMarkedMessage(sprintf('Pre-processing on receiver %d: %s', r, rec(r).getMarkerName()));
                    rec(r).preProcessing();
                end
            end
        end
        
        function runPPP(this, rec, tok)
            % Execute Precise Point Positioning
            %
            % INPUT
            %   rec     list of rec objects
            %   tok     list of tokens(parameters) from command line (cell array)
            %
            % SYNTAX
            %   this.runPPP(rec, tok)
            [id_trg, found] = this.getMatchingRec(rec, tok, 'T');
            if ~found
                this.log.addWarning('No target found -> nothing to do');
            else
                for r = id_trg
                    if rec(r).isStatic
                        this.log.addMarkedMessage(sprintf('StaticPPP on receiver %d: %s', id_trg, rec(r).getMarkerName()));
                        rec(r).staticPPP();
                    else
                        this.log.addError('PPP for moving receiver not yet implemented :-(');
                    end
                end
            end
        end
    
        function runCodePP(this, rec, tok)
            % Execute Code Point Positioning
            %
            % INPUT
            %   rec     list of rec objects
            %   tok     list of tokens(parameters) from command line (cell array)
            %
            % SYNTAX
            %   this.runCodePP(rec, tok)            
            [id_trg, found] = this.getMatchingRec(rec, tok, 'T');
            if ~found
                this.log.addWarning('No target found -> nothing to do');
            else
                for r = id_trg
                    this.log.addMarkedMessage(sprintf('Code positioning on receiver %d: %s', id_trg, rec(r).getMarkerName()));
                    rec(r).initPositioning();
                end
            end
        end
        
        function runSEID(this, rec, tok)
            % Synthesise L2 observations on a target receiver given a set of dual frequency reference stations
            %
            % INPUT
            %   rec     list of rec objects
            %   tok     list of tokens(parameters) from command line (cell array)
            %
            % SYNTAX
            %   this.runSEID(rec, tok)
            [id_trg, found_trg] = this.getMatchingRec(rec, tok, 'T');
            if ~found_trg
                this.log.addWarning('No target found -> nothing to do');
            else
                [id_ref, found_ref] = this.getMatchingRec(rec, tok, 'R');
                if ~found_ref
                    this.log.addWarning('No reference SEID station found -> nothing to do');
                else
                    tic; Core_SEID.getSyntL2(rec(id_ref), rec(id_trg)); toc;
                end
            end
        end
        
        function runKeep(this, rec, tok)
            % Filter Receiver data
            %
            % INPUT
            %   rec     list of rec objects
            %   tok     list of tokens(parameters) from command line (cell array)
            %
            % SYNTAX
            %   this.runKeep(rec, tok)
            [id_trg, found_trg] = this.getMatchingRec(rec, tok, 'T');
            if ~found_trg
                this.log.addWarning('No target found -> nothing to do');
            else
                [rate, found] = this.getRate(tok);
                if found
                    for r = id_trg
                        this.log.addMarkedMessage(sprintf('Keeping a rate of %ds for receiver %d: %s', rate, r, rec(r).getMarkerName()));
                        rec(r).keep(rate);
                    end
                end
                [sys_list, found] = this.getConstellation(tok);
                if found
                    for r = id_trg
                        this.log.addMarkedMessage(sprintf('Keeping constellations "%s" for receiver %d: %s', sys_list, r, rec(r).getMarkerName()));
                        rec(r).keep([], sys_list);
                    end
                end
            end
        end
    end
    %% METHODS STATIC UTILITIES
    % ==================================================================================================================================================
    methods        
        function [id_rec, found, matching_rec] = getMatchingRec(this, rec, tok, type)
            if nargin == 2
                type = 'T';
            end
            id_rec = [];
            found = false;
            matching_rec = [];
            t = 0;
            while ~found && t < numel(tok)
                t = t + 1;
                % Search receiver identified after the key character "type"
                if ~isempty(tok{t}) && tok{t}(1) == type
                    % Analyse all the receiver identified on the string
                    % e.g. T*        all the receivers
                    %      T1,3:5    receiver 1,3,4,5
                    str_rec = tok{t}(2:end);
                    take_all = ~isempty(regexp(str_rec,'[\*]*', 'once'));
                    if take_all
                        id_rec = 1 : numel(rec);
                    else
                        [ids, pos_ids] = regexp(str_rec,'[0-9]*', 'match');
                        ids = str2double(ids);
                        pos_colon = regexp(str_rec,':*');
                        for p = 1 : numel(pos_colon)
                            id_before = find(pos_ids(:) < pos_colon(p), 1, 'last');
                            id_after = find(pos_ids(:) > pos_colon(p), 1, 'first');
                            if ~isempty(id_before) && ~isempty(id_after)
                                id_rec = [id_rec ids(id_before) : ids(id_after)];
                            end
                        end
                        id_rec = unique([ids id_rec]);
                    end
                    found = ~isempty(id_rec);
                    matching_rec = rec(id_rec);
                end
            end            
        end
        
        function [rate, found] = getRate(this, tok)
            found = false;
            rate = [];
            
            t = 0;
            while ~found && t < numel(tok)
                t = t + 1;
                rate = str2double(regexp(tok{t}, ['(?<=' this.PAR_RATE.par ')[+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)*'], 'match'));
                if ~isempty(rate)
                    rate = rate(1);
                    found = true;
                end
            end            
        end
        
        function [sys, found] = getConstellation(this, tok)
            found = false;
            sys = [];
            
            t = 0;
            while ~found && t < numel(tok)
                t = t + 1;
                sys = regexp(tok{t}, ['(?<=' this.PAR_SS.par ')[GREJCIS]*'], 'match');
                if ~isempty(sys)
                    sys = [sys{:}];
                    found = true;
                end
            end            
        end
        
        function [cmd, err, id] = getCommandValidity(this, str)
            err = 0;
            tok = regexp(str,'[^ ]*', 'match');
            str = tok{1};
            id = this.CMD_ID((strcmp(str, this.VALID_CMD)));
            if isempty(id)
                cmd = [];
                err = this.ERR_UNK; % command unknown
            else
                cmd = this.(sprintf('CMD_%s', this.CMD_LIST{id}));
                if numel(tok) < (1 + numel(cmd.rec))
                    err = this.ERR_NEI; % not enough input parameters
                elseif numel(tok) > (1 + numel(cmd.rec) + numel(cmd.par))
                    err = this.WRN_TMI; % too many input parameters
                end
                
            end
        end
        
        function [cmd_list, err_list] = fastCheck(this, cmd_list)
            err_list = zeros(size(cmd_list));
            for c = 1 : numel(cmd_list)
                [~, err_list(c)] = this.getCommandValidity(cmd_list{c});
                
                if err_list(c) > 0
                    this.log.addError(sprintf('%s - cmd %03d "%s"', this.STR_ERR{abs(err_list(c))}, c, cmd_list{c}));
                end
                if err_list(c) < 0
                    this.log.addWarning(sprintf('%s - cmd %03d "%s"', this.STR_ERR{abs(err_list(c))}, c, cmd_list{c}));
                end
            end
            cmd_list = cmd_list(err_list == 0);
        end
    end
    
    methods % Public Access (Legacy support)
        
    end
end