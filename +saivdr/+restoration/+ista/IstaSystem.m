classdef IstaSystem < saivdr.restoration.AbstIterativeMethodSystem
    % ISTASYSTEM Signal restoration via iterative soft thresholding algorithm
    %
    % Problem setting:
    %
    %    r^ = Dx^
    %    x^ = argmin_x (1/2)||y - PDx||_2^2 + lambda ||x||_1
    %
    % Input:
    %
    %    y : Observation
    %    P : Measurment process
    %    D : Synthesis dictionary
    %
    % Output:
    %
    %    r^: Restoration
    %
    % ===================================================================
    %  Iterative soft thresholding algorithm (ISTA)
    % -------------------------------------------------------------------
    % Input:  x(0)
    % Output: r(n)
    %  1: n = 0
    %  2: r(0) = Dx(0)
    %  3: while A stopping criterion is not satisfied do
    %  4:     t <- D'P'(Pr(n) - y)
    %  5:     x(n+1) = G_R( x(n) - gamma*t, sqrt(lambda*gamma) )
    %  6:     r(n+1) = Dx(n+1)
    %  7:     n <- n+1
    %  8: end while
    % ===================================================================
    %  G_R(x,sigma) = sign(x).*max(|x|-sigma^2,0) for R=||.||_1, and
    %  gamma = 1/L, where L is the Lipcitz constant of the gradient of the
    %  1st term.
    % -------------------------------------------------------------------
    %
    % Reference:
    %
    %
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


    properties(Access = private)
        X
        Scales
    end

    methods
        function obj = IstaSystem(varargin)
            import saivdr.restoration.AbstIterativeMethodSystem
            obj = obj@saivdr.restoration.AbstIterativeMethodSystem(...
                varargin{:});
            setProperties(obj,nargin,varargin{:})
        end
    end
    
    methods(Access = protected)
        
        function s = saveObjectImpl(obj)
            s = saveObjectImpl@saivdr.restoration.AbstIterativeMethodSystem(...
                obj);
            s.Scales = obj.Scales;
            s.X      = obj.X;
            %s.Var = obj.Var;
            %s.Obj = matlab.System.saveObject(obj.Obj);
            %if isLocked(obj)
            %    s.Iteration = obj.Iteration;
            %end
        end
        
        function loadObjectImpl(obj,s,wasLocked)
            %if wasLocked
            %    obj.Iteration = s.Iteration;
            %end
            %obj.Obj = matlab.System.loadObject(s.Obj);
            %obj.Var = s.Var;
            obj.X      = s.X;            
            obj.Scales = s.Scales;            
            loadObjectImpl@saivdr.restoration.AbstIterativeMethodSystem(...
                obj,s,wasLocked);
        end
        
        function setupImpl(obj)
            setupImpl@saivdr.restoration.AbstIterativeMethodSystem(obj);
            % Observation
            vObs = obj.Observation;
            % Dictionarie
            fwdDic = obj.Dictionary{obj.FORWARD};
            adjDic = obj.Dictionary{obj.ADJOINT};
            % Measurement process
            msrProc = obj.MeasureProcess;
            
            % Calculation of step size parameter
            framebound = fwdDic.FrameBound;
            step(msrProc,vObs);
            obj.Gamma = 1/(framebound*msrProc.LambdaMax);               

            % Adjoint of measuremnt process
            adjProc = msrProc.clone();
            adjProc.release();
            adjProc.ProcessingMode = 'Adjoint';            
            obj.AdjointProcess = adjProc;
            
            % Initialization
            obj.Result = zeros(size(vObs),'like',vObs);
            if isempty(obj.SplitFactor)
                [obj.X,obj.Scales] = adjDic.step(obj.Result);
            else
                import saivdr.restoration.*
                gamma  = obj.Gamma;
                lambda = obj.Lambda;
                threshold = gamma*lambda;    
                % TODO: Replace to GaussianDenoiserSfth                             
                softthresh = @(x) sign(x).*max(abs(x)-threshold,0);
                cm = CoefsManipulator(...
                    'Manipulation',...
                    @(t,cpre) softthresh(cpre-gamma*t));
                if strcmp(obj.DataType,'Volumetric Data')
                    obj.ParallelProcess = OlsOlaProcess3d();
                else
                    obj.ParallelProcess = OlsOlaProcess2d();                    
                end
                obj.ParallelProcess.Synthesizer = fwdDic;
                obj.ParallelProcess.Analyzer    = adjDic;
                obj.ParallelProcess.CoefsManipulator = cm;
                obj.ParallelProcess.SplitFactor = obj.SplitFactor;
                obj.ParallelProcess.PadSize     = obj.PadSize;
                obj.ParallelProcess.UseParallel = obj.UseParallel;
                obj.ParallelProcess.UseGpu      = obj.UseGpu;
                obj.ParallelProcess.IsIntegrityTest = obj.IsIntegrityTest;
                obj.ParallelProcess.Debug       = obj.Debug;
                %
                obj.X = obj.ParallelProcess.analyze(obj.Result);
                obj.ParallelProcess.InitialState = obj.X;
            end
        end
        
        function varargout = stepImpl(obj)
            stepImpl@saivdr.restoration.AbstIterativeMethodSystem(obj)
            % Observation
            vObs = obj.Observation;
            % Measurement process
            msrProc = obj.MeasureProcess;
            adjProc = obj.AdjointProcess;
            
            % Previous state
            resPre = obj.Result;
            xPre   = obj.X;
            
            % Main steps
            g = adjProc.step(msrProc.step(resPre)-vObs);
            if isempty(obj.SplitFactor) % Normal process
                % Dictionaries
                fwdDic = obj.Dictionary{obj.FORWARD};
                adjDic = obj.Dictionary{obj.ADJOINT};
                scales = obj.Scales;
                %
                gamma  = obj.Gamma;
                lambda = obj.Lambda;
                threshold = gamma*lambda;
                % TODO: Replace to GaussianDenoiserSfth                             
                softthresh = @(x) sign(x).*max(abs(x)-threshold,0);
                %
                t = adjDic.step(g);
                x = softthresh(xPre-gamma*t);
                result = fwdDic(x,scales);
                % Update
                obj.X = x;
            else % OLS/OLA process
                result = obj.ParallelProcess(g);
            end
            
            % Output
            if nargout > 0
                varargout{1} = result;
            end
            if nargout > 1
                import saivdr.restoration.AbstIterativeMethodSystem
                varargout{2} = AbstIterativeMethodSystem.rmse(result,resPre);
            end
            
            % Update
            obj.Result = result;
        end        
        
    end
           
    %{
        function setupImpl(obj)
            if obj.IsSizeCompensation
                sizeM = numel(vObs); % �ϑ��f�[�^�T�C�Y
                src   = msrProc.step(vObs,'Adjoint');
                coefs = adjDic.step(src); % �ϊ��W���T�C�Y
                sizeL = numel(coefs);
                obj.LambdaCompensated = obj.Lambda*(sizeM^2/sizeL);
            else
                obj.LambdaCompensated = obj.Lambda;
            end
            lambda_ = obj.LambdaCompensated;
            gamma = 1/lpst; % f�̌��z�̃��v�V�b�c�搔�̋t��
            gdn = PlgGdnSfth('Sigma',sqrt(gamma*lambda_));
    end
    %}
end