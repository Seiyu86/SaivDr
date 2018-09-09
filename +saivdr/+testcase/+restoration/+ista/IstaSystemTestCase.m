classdef IstaSystemTestCase < matlab.unittest.TestCase
    %ISTASYSTEMTESTCASE Test case for IstaSystem
    %
    % Requirements: MATLAB R2015b
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
    
    properties (TestParameter)
        useparallel = struct('true', true, 'false', false );
        niter   = struct('small',1, 'medium', 2, 'large', 4 );
        depth = struct('small',8, 'large', 32);
        hight = struct('small',8, 'large', 32);
        width = struct('small',8, 'large', 32);
        dsplit = struct('small',1, 'large', 2);
        vsplit = struct('small',1, 'large', 2);        
        hsplit = struct('small',1, 'large', 2);                
        nlevels = { 1, 3 };
    end
    
    properties
        target
    end
    
    methods (TestMethodTeardown)
        function deteleObject(testCase)
            delete(testCase.target);
        end
    end    
    
    methods (Test)
        
        function testConstruction(testCase)
            
            % Parameters
            lambdaExpctd  = 0; % Regularization parameter
            gammaExpctd   = 0; % Step size parameter
            msrExpctd = [];
            dicExpctd = [];
            gdnExpctd = [];
            obsExpctd = [];
            
            % Instantiation
            import saivdr.restoration.ista.*
            testCase.target = IstaSystem();
            
            % Actual values
            lambdaActual  = testCase.target.Lambda;  % Regularizaton parameter
            gammaActual  = testCase.target.Gamma;  % Stepsize parameter
            msrActual = testCase.target.MeasureProcess;
            dicActual = testCase.target.Dictionary;
            gdnActual = testCase.target.GaussianDenoiser;
            obsActual = testCase.target.Observation;
            
            % Evaluation
            testCase.verifyEqual(lambdaActual,lambdaExpctd);
            testCase.verifyEqual(gammaActual,gammaExpctd);
            testCase.verifyEqual(msrActual,msrExpctd);
            testCase.verifyEqual(dicActual,dicExpctd);
            testCase.verifyEqual(gdnActual,gdnExpctd);            
            testCase.verifyEqual(obsActual,obsExpctd);                        
            
        end
        
        function testStepVolumetricData(testCase,...
            niter,depth,width,nlevels)
            
            % Parameters
            lambda = 1e-3;
            phtm = phantom('Modified Shepp-Logan',depth);
            sliceYZ = permute(phtm,[1 3 2]);
            uSrc = 0.5*repmat(sliceYZ,[1 width 1]) + 1;
            
            % Instantiation of observation
            import saivdr.degradation.linearprocess.*
            pSigma = 2.00; % Extent of PSF
            wSigma = 1e-3; % Standard deviation of noise
            msrProc = BlurSystem(...
                'BlurType','Gaussian',...
                'SigmaOfGaussianKernel',pSigma,...
                'ProcessingMode','Forward');
            vObs = msrProc.step(uSrc) ...
                + wSigma*randn(size(uSrc));
            
            % Instantiation of dictionary
            import saivdr.dictionary.udhaar.*
            fwdDic  = UdHaarSynthesis3dSystem();
            adjDic  = UdHaarAnalysis3dSystem('NumberOfLevels',nlevels);
            
            % Calculation of step size parameter
            framebound = fwdDic.FrameBound;
            step(msrProc,vObs);
            gammaExpctd = 1/(framebound*msrProc.LambdaMax);
            
            % Expected values
            lambdaExpctd = lambda;
            thr = lambdaExpctd*gammaExpctd;
            softthresh = @(x) sign(x).*max(abs(x)-thr,0);
            %
            [x0,scale] = adjDic.step(zeros(size(vObs),'like',vObs));
            resPre = fwdDic.step(x0,scale);
            adjProc = msrProc.clone();
            adjProc.release();
            adjProc.ProcessingMode = 'Adjoint';
            resExpctd = cell(niter,1);
            xPre = x0;
            for iter = 1:niter
                t = adjDic.step(adjProc.step(msrProc.step(resPre)-vObs));
                x = softthresh(xPre-gammaExpctd*t);
                resExpctd{iter} = fwdDic(x,scale);
                resPre = resExpctd{iter};
                xPre = x;
            end
            
            % Instantiation of test target
            import saivdr.restoration.ista.*
            testCase.target = IstaSystem(...
                'Observation',    vObs,...
                'Lambda',         lambda,...
                'MeasureProcess', msrProc,...
                'Dictionary', { fwdDic, adjDic } );
            
            % Evaluation of 1st step
            eps = 1e-10;
            iterExpctd = 1;
            [resActual,rmseActual] = testCase.target.step();
            iterActual  = testCase.target.Iteration;            
            gammaActual = testCase.target.Gamma;
            lambdaActual = testCase.target.Lambda;
            %
            testCase.verifyEqual(iterActual,iterExpctd)
            testCase.verifyEqual(gammaActual,gammaExpctd)
            testCase.verifyEqual(lambdaActual,lambdaExpctd)            
            %
            testCase.verifySize(resActual,size(uSrc));
            %
            diff = max(abs(resExpctd{iterExpctd}(:)-resActual(:)));
            testCase.verifyEqual(resActual,resExpctd{iterExpctd},...
                'AbsTol',eps,num2str(diff));
            %
            % Evaluation of iterative step     
            import matlab.unittest.constraints.IsLessThan
            rmse = @(x,y) norm(x(:)-y(:),2)/sqrt(numel(x));
            rmsePre = rmseActual;
            resPre  = resActual;
            for iter = 2:niter
                iterExpctd = iterExpctd + 1;
                %
                [resActual,rmseActual] = testCase.target.step();
                iterActual = testCase.target.Iteration;
                %
                testCase.verifyEqual(iterActual,iterExpctd)
                diff = max(abs(resExpctd{iterExpctd}(:)-resActual(:)));
                testCase.verifyEqual(resActual,resExpctd{iterExpctd},...
                'AbsTol',eps,num2str(diff));                
                %
                rmseExpctd = rmse(resActual,resPre);
                diff = max(abs(rmseExpctd-rmseActual));
                testCase.verifyEqual(rmseActual,rmseExpctd,...
                    'AbsTol',eps,num2str(diff));
                %
                testCase.verifyThat(rmseActual,IsLessThan(rmsePre))                
                %
                resPre  = resActual;
            end

        end
        
        %{
        function testStepSplit(testCase,...
                depth,width,dsplit,nlevels,phimode,niter,useparallel)
            
            % �p�����[�^
            splitfactor = [2*ones(1,2) dsplit];
            padsize = 2^(nlevels-1)*ones(1,3);
            phtm = phantom('Modified Shepp-Logan',depth);
            sliceYZ = permute(phtm,[1 3 2]);
            uSrc = 0.5*repmat(sliceYZ,[1 width 1]) + 1;
            
            % �ϑ��f�[�^����
            wSigma = 4e-2; % �m�C�Y���U
            pScale = 8.00; % �����x
            pSigma = 8.00; % �L����
            pFreq  = 0.25; % ���g��
            coh3 = Coherence3(...
                'Scale',pScale,...
                'Sigma',pSigma,...
                'Frequency',pFreq);
            phi  = RefractIdx2Reflect();
            vObs = coh3.step(phi.step(uSrc),'Forward') ...
                + wSigma*randn(size(uSrc));
            
            % �C���X�^���X����
            fwdDic  = DicUdHaarRec3();
            adjDic  = DicUdHaarDec3('NumLevels',nlevels);
            
            reference = IstaOct3(...
                'Observation',    vObs,...
                'PhiMode',        phimode,...
                'MeasureProcess', coh3,...
                'Dictionary', { fwdDic, adjDic } );
            
            target = IstaOct3(...
                'Observation',    vObs,...
                'PhiMode',        phimode,...
                'MeasureProcess', coh3,...
                'Dictionary', { fwdDic, adjDic } ,...
                'SplitFactor',splitfactor,...
                'PadSize',padsize,...
                'UseParallel',useparallel);
            
            % ��������
            for iter = 1:niter
                resExpctd = reference.step();
                resActual = target.step();
            end
            
            % �]��
            %import matlab.unittest.constraints.IsLessThan
            testCase.verifySize(resActual,size(resExpctd));
            diff = max(abs(resExpctd(:) - resActual(:)));
            testCase.verifyEqual(resActual,resExpctd,...
                'AbsTol',1e-4,sprintf('%g',diff));
            
        end
        %}
    end

end