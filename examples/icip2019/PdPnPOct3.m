classdef PdPnPOct3 < matlab.System
    % PDPNPOCT3 ��o�Ε����v���O���v���C�@�ɂ��OCT�f�[�^����
    %
    % Output
    %
    %    ���˗����z
    %
    % Reference
    %
    % - ��������C���X�x�C����s�C�C�ɓ��v���C ���c�x�C �C���W�C�����_�i�V����j
    %   �񕉐���𗘗p���� en-face OCT�{�����[���f�[�^�M�������C
    %   ��32��M�������V���|�W�E���C�����C2017�N11��8-10��
    %
    % - Shogo Muramatsu, Samuel Choi, Shunske Ono, Takeru Ota, Fumiaki Nin,
    %   Hiroshi Hibino: 
    %   OCT Volumetric Data Restoration via Primal-Dual Plug-and-Play Method, 
    %   Proc. of 2016 IEEE International Conference on Acoustics, Speech and 
    %   Signal Processing (ICASSP), Apr. 2018
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
        Gamma1  = 0.01     % �X�e�b�v�T�C�Y
        Gamma2  = []
        VRange  = [ -1.00 1.00 ]  % �n�[�h����
        IsNoDcShrink = false     % �����\�t�g臒l�������
        %
        MeasureProcess
        Dictionary
        GaussianDenoiser
        %
        SplitFactor = []
        PadSize     = [ 0 0 0 ]
    end
    
    properties (GetAccess = public, SetAccess = private)
        Result
        LambdaCompensated
    end
    
    properties(Nontunable, Access = private)
        dltFcn
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
    
    properties(DiscreteState)
        Iteration
    end
  
    methods
        function obj = PdPnPOct3(varargin)
            setProperties(obj,nargin,varargin{:})
            %
            obj.dltFcn = Sobel3d('KernelMode','Normal');
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
            obj.parProc = matlab.System.loadObject(s.parProc);
            obj.Result = s.Result;
            obj.y1 = s.y1;
            obj.y2 = s.y2;
            obj.xpre = s.xpre;
            obj.scls = s.scls;
            loadObjectImpl@matlab.System(obj,s,wasLocked);
        end
        
        
        function setupImpl(obj)
            % Perform one-time calculations, such as computing constants
            vObs    = obj.Observation;
            msrProc = obj.MeasureProcess;
            fwdDic  = obj.Dictionary{1};                  
            adjDic  = obj.Dictionary{2};      

            if obj.IsSizeCompensation
                sizeM = numel(vObs); % �ϑ��f�[�^�T�C�Y
                src   = msrProc.step(vObs,'Adjoint');
                coefs = adjDic.step(src); % �ϊ��W���T�C�Y
                sizeL = numel(coefs);
                obj.LambdaCompensated = obj.Lambda*(sizeM^2/sizeL);
            else
                obj.LambdaCompensated = obj.Lambda;
            end
            gamma1_ = obj.Gamma1;

            % P�̍ő���ْl�v�Z
            xpst_   = rand(size(vObs));
            lpre    = 1.0;
            err_    = Inf;
            cnt_    = 0;
            maxCnt_ = 1000;
            tolPm_  = 1e-3;
            % Power method
            while ( err_ > tolPm_ )
                cnt_ = cnt_ + 1;
                % xpre = xpst/||xpst||
                xpre_ = xpst_/norm(xpst_(:));
                % xpst = (P.'*P)*xpre
                xpst_ = msrProc(msrProc(xpre_,'Forward'),'Adjoint');
                n = (xpst_(:).'*xpre_(:));
                d = (xpre_(:).'*xpre_(:));
                lpst = n/d;
                err_ = abs(lpst-lpre)/abs(lpre);
                lpre = lpst;
                if cnt_ >= maxCnt_
                    warning('# of iterations reached to maximum');
                    break;
                end
            end
            tauSqd = lpst+1;
            obj.Gamma2 = 1/(gamma1_*(1.05*tauSqd));
            %
            obj.GaussianDenoiser.release();
            obj.GaussianDenoiser.Sigma = sqrt(gamma1_);

            %������
            obj.y1 = zeros(size(vObs),'like',vObs);
            obj.y2 = zeros(size(vObs),'like',vObs);
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
                gdn = obj.GaussianDenoiser;
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
            vObs    = obj.Observation;
            msrProc = obj.MeasureProcess;            
            %
            vmin = obj.VRange(1);
            vmax = obj.VRange(2);
            lambda_ = obj.LambdaCompensated;            
            gamma2_ = obj.Gamma2;
            %
            y1_  = obj.y1;
            y2_  = obj.y2;
            rpre = obj.Result;
            prx_ = msrProc.step(y1_,'Adjoint') + y2_;
            if isempty(obj.SplitFactor) % Normal process
                fwdDic  = obj.Dictionary{1};            
                adjDic  = obj.Dictionary{2};
                gdnFcn = obj.GaussianDenoiser;                
                %
                scls_ = obj.scls;
                xpre_ = obj.xpre;
                gamma1_ = obj.Gamma1;                
                %
                t = adjDic.step(prx_); % ���͏���
                x = gdnFcn.step(xpre_-gamma1_*t); % �W������              
                v = fwdDic.step(x,scls_); %��������
                %
                obj.xpre = x;
            else % OLS/OLA ���͍�������
                v = obj.parProc.step(prx_);
            end
            u = 2*v - rpre;
            % lines 3-4
            y1_ = y1_ + gamma2_*msrProc.step(u,'Forward');
            y2_ = y2_ + gamma2_*u;
            % lines 5-6 
            y1_ = y1_ - gamma2_/(1+gamma2_*lambda_)*(lambda_*y1_+vObs);
            pcy2 = y2_/gamma2_;
            pcy2((y2_/gamma2_)<vmin) = vmin;
            pcy2((y2_/gamma2_)>vmax) = vmax;
            y2_ = y2_ - gamma2_*pcy2;
            %
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
            %            
            
        end

        function resetImpl(obj)
            % Initialize / reset discrete-state properties
            obj.Iteration = 0;
        end
    end
    
end