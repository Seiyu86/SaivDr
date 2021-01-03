classdef PdsHsHcOct3 < matlab.System
    % PDSHSHCOCT3 �K�w�I�X�p�[�X���ƃn�[�h����𗘗p������o�΋ߐڕ����@
    %
    % Output
    %
    %    ���ܗ������z
    %
    % Reference
    %
    % - ��������E���R�m�i�E���@�X�x�i�V����j�E����s�C�i���H��j�E
    %   ���c�@�x�E�C�@���W�E�����@�_�i�V����j
    %   �K�w�I�X�p�[�X�������ƃn�[�h����𗘗p����OCT�{�����[���f�[�^�����̌����C
    %   �d�q���ʐM�w��M������������C�򕌑�C2018�N5��
    %
    % - ���䌳��E��������E���@�X�x�i�V����j�E����s�C�i���H��j�E
    %   ���c�@�x�E�C�@���W�E�����@�_�i�V����j�C
    %   �K�w�I�X�p�[�X�������ƃn�[�h����𗘗p����OCT�{�����[���f�[�^������
    %   ���f�[�^���؁C�d�q���ʐM�w��M������������C��啶���L�����p�X�C2018�N8��
    %
    % Requirements: MATLAB R2018a
    %
    % Copyright (c) 2018, Shogo MURAMATSU
    %
    % All rights reserved.
    %
    % Contact address: Shogo MURAMATSU,
    %                Faculty of Engineering, Niigata University,
    %                8050 2-no-cho Ikarashi, Nishi-ku,
    %                Niigata, 950-2181, JAPAN
    %
    % http://msiplab.eng.niigata-u.ac.jp/
    %
    
    % Public, tunable properties
    properties (Nontunable)
        Observation
        Lambda  = 0.01     % �������p�����[�^
        Eta     = 0.01     % �������p�����[�^
        Gamma1  = 0.01     % �X�e�b�v�T�C�Y
        Gamma2  = []
        Beta    = 0.0      % �������̌��z�̃��v�V�b�c�萔
        VRange  = [ 1.00 1.50 ]  % �n�[�h����
        PhiMode = 'Linear'       % ���`��
        IsNoDcShrink = false     % �����\�t�g臒l�������
        IsEnvelopeWeight = false % ����d�݂Â�
        %
        MeasureProcess
        Dictionary
        GaussianDenoiser
        %
        SplitFactor = []
        PadSize     = [ 0 0 0 ]
        %
    end
    
    properties (GetAccess = public, SetAccess = private)
        Result
        LambdaCompensated
        EtaCompensated
    end
    
    properties(Nontunable, Access = private)
        dltFcn
        grdFcn
        parProc
    end
    
    properties(Nontunable, Logical)
        IsIntegrityTest = true
        IsSizeCompensation = false
        UseParallel = false
        UseGpu = false
    end
    
    properties(Nontunable,Logical, Hidden)
        Debug = false
    end
    
    properties(Access = private)
        y1
        y2
        xpre
        scls
    end
    
    properties (Hidden)
        PhiModeSet = ...
            matlab.system.StringSet(...
            {'Reflection','Linear','Signed-Quadratic','Identity'});
    end
    
    properties(DiscreteState)
        Iteration
    end
    
    methods
        function obj = PdsHsHcOct3(varargin)
            setProperties(obj,nargin,varargin{:})
            %
            obj.dltFcn = Sobel3d(...
                'KernelMode','Normal',...
                'UseGpu',obj.UseGpu);
            phi_ = RefractIdx2Reflect(...
                'PhiMode',obj.PhiMode,...
                'VRange',obj.VRange,...
                'UseGpu',obj.UseGpu);
            obj.grdFcn = CostEvaluator(...
                'Observation',obj.Observation,...
                'MeasureProcess',obj.MeasureProcess,...
                'RefIdx2Ref',phi_,...
                'OutputMode','Gradient',...
                'UseGpu',obj.UseGpu);
            %
            if isempty(obj.Gamma2)
                tauSqd     = obj.dltFcn.LambdaMax + 1;
                obj.Gamma2 = 1/(1.05*tauSqd)*(1/obj.Gamma1-obj.Beta/2);
            end
        end
    end
    
    methods(Access = protected)
        
        function s = saveObjectImpl(obj)
            s = saveObjectImpl@matlab.System(obj);
            s.Result = obj.Result;
            s.y1 = obj.y1;
            s.y2 = obj.y2;
            s.xpre = obj.xpre;
            s.scls = obj.scls;
            s.dltFcn = matlab.System.saveObject(obj.dltFcn);
            s.grdFcn = matlab.System.saveObject(obj.grdFcn);
            s.parProc = matlab.System.saveObject(obj.parProc);
            s.Dictionary{1} = matlab.System.saveObject(obj.Dictionary{1});
            s.Dictionary{2} = matlab.System.saveObject(obj.Dictionary{2});
            if isLocked(obj)
                s.Iteration = obj.Iteration;
            end
        end
        
        function loadObjectImpl(obj,s,wasLocked)
            if wasLocked
                obj.Iteration = s.Iteration;
            end
            obj.Dictionary{1} = matlab.System.loadObject(s.Dictionary{1});
            obj.Dictionary{2} = matlab.System.loadObject(s.Dictionary{2});
            obj.dltFcn = matlab.System.loadObject(s.dltFcn);
            obj.grdFcn = matlab.System.loadObject(s.grdFcn);
            obj.parProc = matlab.System.loadObject(s.parProc);
            obj.Result = s.Result;
            obj.xpre = s.xpre;
            obj.scls = s.scls;
            obj.y1 = s.y1;
            obj.y2 = s.y2;
            loadObjectImpl@matlab.System(obj,s,wasLocked);
        end
        
        
        function setupImpl(obj)
            % Perform one-time calculations, such as computing constants
            vObs = obj.Observation;
            msrProc = obj.MeasureProcess;            
            fwdDic  = obj.Dictionary{1};
            adjDic  = obj.Dictionary{2};
            %
            if obj.IsSizeCompensation
                sizeM = numel(vObs); % �ϑ��f�[�^�T�C�Y
                src   = msrProc.step(vObs,'Adjoint');
                sizeN = numel(src); % ���ܗ����z�T�C�Y
                coefs = adjDic.step(src); % �ϊ��W���T�C�Y
                sizeL = numel(coefs);
                obj.LambdaCompensated = obj.Lambda*(sizeM^2/sizeL);
                obj.EtaCompensated    = obj.Eta*(sizeM^2/sizeN);
            else
                obj.LambdaCompensated = obj.Lambda;
                obj.EtaCompensated    = obj.Eta;
            end
            %
            lambda_ = obj.LambdaCompensated;
            eta_    = obj.EtaCompensated;
            gamma1_ = obj.Gamma1;
            gamma2_ = obj.Gamma2;
            %
            obj.GaussianDenoiser{1}.release();
            obj.GaussianDenoiser{1}.Sigma = sqrt(gamma1_*lambda_);
            obj.GaussianDenoiser{2}.release();
            obj.GaussianDenoiser{2}.Sigma = sqrt(eta_/gamma2_);
            
            %������
            obj.y1 = zeros(1,'like',vObs);
            obj.y2 = zeros(1,'like',vObs);
            obj.Result = zeros(1,'like',vObs);
            res0 = zeros(size(vObs),'like',vObs);
            if isempty(obj.SplitFactor) % Normal process
                obj.parProc = [];
                %
                fwdDic.release();
                obj.Dictionary{1} = fwdDic.clone();
                adjDic.release();
                obj.Dictionary{2} = adjDic.clone();
                %
                [obj.xpre,obj.scls] = adjDic(res0); % �ϊ��W���̏����l
            else
                import saivdr.restoration.*
                gdn = obj.GaussianDenoiser{1};
                cm = CoefsManipulator(...
                    'Manipulation',...
                    @(t,cpre)  gdn.step(cpre-gamma1_*t));
                obj.parProc = OlsOlaProcess3d(...
                    'Synthesizer',fwdDic,...
                    'Analyzer',adjDic,...
                    'CoefsManipulator',cm,...
                    'SplitFactor',obj.SplitFactor,...
                    'PadSize',obj.PadSize,...
                    'UseParallel',obj.UseParallel,...
                    'UseGpu',obj.UseGpu,...
                    'IsIntegrityTest',obj.IsIntegrityTest,...
                    'Debug',obj.Debug);
                obj.xpre = obj.parProc.analyze(res0); % �ϊ��W���̏����l
                obj.parProc.InitialState = obj.xpre;
            end
            
        end
        
        function varargout = stepImpl(obj)
            % Implement algorithm. Calculate y as a function of input u and
            % discrete states.
            dltFcn_ = obj.dltFcn;
            grdFcn_ = obj.grdFcn;
            %
            vmin = obj.VRange(1);
            vmax = obj.VRange(2);
            gamma2_ = obj.Gamma2;
            gdnFcnH = obj.GaussianDenoiser{2};
            %
            y1_  = obj.y1;
            y2_  = obj.y2;
            rpre = obj.Result;
            prx_ = grdFcn_.step(rpre) + (-dltFcn_.step(y1_)) + y2_;
            if isempty(obj.SplitFactor) % Normal process
                fwdDic  = obj.Dictionary{1};
                adjDic  = obj.Dictionary{2};
                gdnFcnG = obj.GaussianDenoiser{1};
                %
                scls_ = obj.scls;
                xpre_ = obj.xpre;
                gamma1_ = obj.Gamma1;
                %
                t = adjDic.step(prx_); % ���͏���
                x = gdnFcnG.step(xpre_-gamma1_*t); % �W������
                v = fwdDic.step(x,scls_); % ��������
                %
                obj.xpre = x;
            else % OLS/OLA ���͍�������
                v = obj.parProc.step(prx_);
            end
            u = 2*v - rpre;
            % lines 6-7
            y1_ = y1_ + gamma2_*dltFcn_.step(u);
            y2_ = y2_ + gamma2_*u;
            % line 8
            y1_ = y1_ - gamma2_*gdnFcnH.step( y1_/gamma2_ );
            % line 9
            pcy2 = y2_/gamma2_;
            pcy2((y2_/gamma2_)<vmin) = vmin;
            pcy2((y2_/gamma2_)>vmax) = vmax;
            y2_ = y2_ - gamma2_*pcy2;
            % line 10
            r = (u+rpre)/2;
            
            % �o��
            if nargout > 0
                varargout{1} = r;
            end
            if nargout > 1
                rmse = norm(r(:)-rpre(:),2)/norm(r(:),2);
                varargout{2} = rmse;
            end
            
            % ��ԍX�V
            obj.y1 = y1_;
            obj.y2 = y2_;
            obj.Result = r;
            obj.Iteration = obj.Iteration + 1;
        end
        
        function resetImpl(obj)
            % Initialize / reset discrete-state properties
            obj.Iteration = 0;
        end
    end
  
end