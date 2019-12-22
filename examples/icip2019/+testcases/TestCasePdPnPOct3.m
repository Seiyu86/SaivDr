classdef TestCasePdPnPOct3 < matlab.unittest.TestCase
    %TESTCASEPDPNPOCT3 ���̃N���X�̊T�v�������ɋL�q
    %   �ڍא����������ɋL�q
    
    properties (TestParameter)
        %         scl  = struct('small',0.1, 'large', 10.0);
        %         sgm  = struct('small',0.1, 'large', 10.0);
        useparallel = struct('true', true, 'false', false );        
        niter   = struct('small',1, 'large', 4 );
        vrange  = struct('low',[1.0 1.5], 'high', [1.5 2.0]);
        depth = struct('small',8, 'large', 32);
        width = struct('small',8, 'large', 32);
        dsplit = struct('small',1, 'large', 4);
        nlevels = { 1, 3 };
    end
    
    methods (Test)
        
        function testConstruction(testCase)
            
            % �p�����[�^�i���Ғl�j
            lambdaExpctd  = 0.01;     % �������p�����[�^
            gamma1Expctd  = 0.01;     % �X�e�b�v�T�C�Y
            vrangeExpctd  = [ -1.00 1.00 ];     % �n�[�h���񉺌�
            isNoDcShrinkExpctd = false;  % �����\�t�g臒l�������
            
            % �C���X�^���X����
            target = PdPnPOct3();
            
            % �����l
            lambdaActual  = target.Lambda;  % �������p�����[�^
            gamma1Actual  = target.Gamma1;  % �X�e�b�v�T�C�Y
            vrangeActual  = target.VRange;  % �n�[�h���񉺌�
            isNoDcShrinkActual = target.IsNoDcShrink;  % �����\�t�g臒l�������
            
            % �]��
            testCase.verifyEqual(lambdaActual,lambdaExpctd);
            testCase.verifyEqual(gamma1Actual,gamma1Expctd);
            testCase.verifyEqual(vrangeActual,vrangeExpctd);
            testCase.verifyEqual(isNoDcShrinkActual,isNoDcShrinkExpctd);
            
        end
        
        function testStep(testCase,...
                depth,width,nlevels,niter)
            
            % �p�����[�^
            phtm = phantom('Modified Shepp-Logan',depth);
            sliceYZ = permute(phtm,[1 3 2]);
            uSrc = 0.5*repmat(sliceYZ,[1 width 1]) + 1;
            
            % ���Ғl
            iterExpctd = niter;
            
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
            import saivdr.dictionary.udhaar.*
            import saivdr.restoration.denoiser.*
            fwdDic  = UdHaarSynthesis3dSystem();
            adjDic  = UdHaarAnalysis3dSystem('NumberOfLevels',nlevels);
            gdnFcn  = GaussianDenoiserSfth();
            target  = PdPnPOct3(...
                'Observation',    vObs,...
                'MeasureProcess', coh3,...
                'Dictionary', { fwdDic, adjDic },...
                'GaussianDenoiser', gdnFcn );
            
            % ��������
            for iter = 1:iterExpctd
                r = target.step();
            end
            iterActual = target.Iteration;
            
            % �]��
            %import matlab.unittest.constraints.IsLessThan
            testCase.verifySize(r,size(uSrc));
            testCase.verifyEqual(iterActual,iterExpctd)
            
        end
        
        function testStepBm4d(testCase,depth,width,niter)
            
            % �p�����[�^
            phtm = phantom('Modified Shepp-Logan',depth);
            sliceYZ = permute(phtm,[1 3 2]);
            uSrc = 0.5*repmat(sliceYZ,[1 width 1]) + 1;
            
            % ���Ғl
            iterExpctd = niter;
            
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
            import saivdr.dictionary.utility.*
            import saivdr.restoration.denoiser.*
            fwdDic  = IdentitySynthesisSystem();
            adjDic  = IdentityAnalysisSystem('IsVectorize',false);
            gdnFcn = GaussianDenoiserBm4d();
            target  = PdPnPOct3(...
                'Observation',    vObs,...
                'MeasureProcess', coh3,...
                'Dictionary', { fwdDic, adjDic },...
                'GaussianDenoiser', gdnFcn );
            
            % ��������
            for iter = 1:iterExpctd
                r = target.step();
            end
            iterActual = target.Iteration;
            
            % �]��
            %import matlab.unittest.constraints.IsLessThan
            testCase.verifySize(r,size(uSrc));
            testCase.verifyEqual(iterActual,iterExpctd)
            
        end
        
        function testStepHdth(testCase,depth,width,niter,nlevels)
            
            % �p�����[�^
            phtm = phantom('Modified Shepp-Logan',depth);
            sliceYZ = permute(phtm,[1 3 2]);
            uSrc = 0.5*repmat(sliceYZ,[1 width 1]) + 1;
            
            % ���Ғl
            iterExpctd = niter;
            
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
            import saivdr.dictionary.udhaar.*
            import saivdr.restoration.denoiser.*
            fwdDic  = UdHaarSynthesis3dSystem();
            adjDic  = UdHaarAnalysis3dSystem('NumberOfLevels',nlevels);
            gdnFcn  = GaussianDenoiserHdth();
            target  = PdPnPOct3(...
                'Observation',    vObs,...
                'MeasureProcess', coh3,...
                'Dictionary', { fwdDic, adjDic },...
                'GaussianDenoiser', gdnFcn );
            
            % ��������
            for iter = 1:iterExpctd
                r = target.step();
            end
            iterActual = target.Iteration;
            
            % �]��
            %import matlab.unittest.constraints.IsLessThan
            testCase.verifySize(r,size(uSrc));
            testCase.verifyEqual(iterActual,iterExpctd)
            
        end
        
        
        function testStepSplit(testCase,...
                depth,width,dsplit,nlevels,niter,useparallel)
            
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
            import saivdr.dictionary.udhaar.*
            import saivdr.restoration.denoiser.*
            fwdDic  = UdHaarSynthesis3dSystem();
            adjDic  = UdHaarAnalysis3dSystem('NumberOfLevels',nlevels);
            gdnFcn  = GaussianDenoiserSfth();
            
            reference  = PdPnPOct3(...
                'Observation',    vObs,...
                'MeasureProcess', coh3,...
                'Dictionary', { fwdDic, adjDic },...
                'GaussianDenoiser', gdnFcn);
                        
            target  = PdPnPOct3(...
                'Observation',    vObs,...
                'MeasureProcess', coh3,...
                'Dictionary', { fwdDic, adjDic },...
                'GaussianDenoiser', gdnFcn,...
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
        
    end
    
end