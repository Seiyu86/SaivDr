classdef TestCasePdsHsHcOct3 < matlab.unittest.TestCase
    %UDHAARDEC3TESTCASE ���̃N���X�̊T�v�������ɋL�q
    %   �ڍא����������ɋL�q
    
    properties (TestParameter)
        %         scl  = struct('small',0.1, 'large', 10.0);
        %         sgm  = struct('small',0.1, 'large', 10.0);
        useparallel = struct('true', true, 'false', false );        
        niter   = struct('small',1, 'large', 4 );
        vrange  = struct('low',[1.0 1.5], 'high', [1.5 2.0]);
        phimode = {'Reflection','Linear' }; %,'Signed-Quadratic' };
        depth = struct('small',8, 'large', 32);
        width = struct('small',8, 'large', 32);
        dsplit = struct('small',1, 'large', 4);
        nlevels = { 1, 3 };
    end
    
    methods (Test)
        
        function testConstruction(testCase)
            
            % �p�����[�^�i���Ғl�j
            lambdaExpctd  = 0.01;     % �������p�����[�^
            etaExpctd     = 0.01;     % �������p�����[�^
            gamma1Expctd  = 0.01;     % �X�e�b�v�T�C�Y
            vrangeExpctd  = [ 1.00 1.50 ];     % �n�[�h���񉺌�
            phiModeExpctd = 'Linear'; % ���`��
            isNoDcShrinkExpctd = false;  % �����\�t�g臒l�������
            isEnvelopeWeightExpctd = false;  % ����d�݂Â�
            
            % �C���X�^���X����
            target = PdsHsHcOct3();
            
            % �����l
            lambdaActual  = target.Lambda;  % �������p�����[�^
            etaActual     = target.Eta;     % �������p�����[�^
            gamma1Actual  = target.Gamma1;  % �X�e�b�v�T�C�Y
            vrangeActual  = target.VRange;  % �n�[�h���񉺌�
            phiModeActual = target.PhiMode; % ���`��
            isNoDcShrinkActual = target.IsNoDcShrink;  % �����\�t�g臒l�������
            isEnvelopeWeightActual = target.IsEnvelopeWeight;  % ����d�݂Â�
            
            % �]��
            testCase.verifyEqual(lambdaActual,lambdaExpctd);
            testCase.verifyEqual(etaActual,etaExpctd);
            testCase.verifyEqual(gamma1Actual,gamma1Expctd);
            testCase.verifyEqual(vrangeActual,vrangeExpctd);
            testCase.verifyEqual(phiModeActual,phiModeExpctd);
            testCase.verifyEqual(isNoDcShrinkActual,isNoDcShrinkExpctd);
            testCase.verifyEqual(isEnvelopeWeightActual,isEnvelopeWeightExpctd);
            
        end
        
        
        function testStep(testCase,...
                depth,width,nlevels,phimode,vrange,niter)
            
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
            %fwdDic = DicUdHaarRec3();
            %adjDic = DicUdHaarDec3('NumLevels',nLevels);
            %gdnFcnG = PlgGdnSfth();
            %gdnFcnH = PlgGdnSfth();
            fwdDic = UdHaarSynthesis3dSystem();
            adjDic = UdHaarAnalysis3dSystem('NumberOfLevels',nlevels);
            gdnFcnG = GaussianDenoiserSfth();
            gdnFcnH = GaussianDenoiserSfth();
            target  = PdsHsHcOct3(...
                'Observation',    vObs,...
                'PhiMode',        phimode,...
                'VRange',         vrange,...
                'MeasureProcess', coh3,...
                'Dictionary', { fwdDic, adjDic },...
                'GaussianDenoiser', { gdnFcnG, gdnFcnH } );
            
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
            %fwdDic  = DicIdentityRec();
            %adjDic  = DicIdentityDec('IsVectorize',false);
            fwdDic  = IdentitySynthesisSystem();
            adjDic  = IdentityAnalysisSystem('IsVectorize',false);            
            %gdnFcnG = PlgGdnBm4d();
            %gdnFcnH = PlgGdnSfth();
            gdnFcnG = GaussianDenoiserBm4d();
            gdnFcnH = GaussianDenoiserSfth();            
            target  = PdsHsHcOct3(...
                'Observation',    vObs,...
                'MeasureProcess', coh3,...
                'Dictionary', { fwdDic, adjDic },...
                'GaussianDenoiser', { gdnFcnG, gdnFcnH } );
            
            % ��������
            for niter = 1:iterExpctd
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
            %fwdDic = DicUdHaarRec3();
            %adjDic = DicUdHaarDec3('NumLevels',nLevels);
            %gdnFcnG = PlgGdnSfth();
            %gdnFcnH = PlgGdnSfth();
            fwdDic = UdHaarSynthesis3dSystem();
            adjDic = UdHaarAnalysis3dSystem('NumberOfLevels',nlevels);
            gdnFcnG = GaussianDenoiserSfth();
            gdnFcnH = GaussianDenoiserSfth();
            target  = PdsHsHcOct3(...
                'Observation',    vObs,...
                'MeasureProcess', coh3,...
                'Dictionary', { fwdDic, adjDic },...
                'GaussianDenoiser', { gdnFcnG, gdnFcnH } );
            
            % ��������
            for niter = 1:iterExpctd
                r = target.step();
            end
            iterActual = target.Iteration;
            
            % �]��
            %import matlab.unittest.constraints.IsLessThan
            testCase.verifySize(r,size(uSrc));
            testCase.verifyEqual(iterActual,iterExpctd)
            
        end
        
        
        function testStepSplit(testCase,...
                depth,width,dsplit,nlevels,phimode,vrange,niter,useparallel)
            
            % �p�����[�^
            splitfactor = [2*ones(1,2) dsplit];
            padsize = 2^(nlevels-1)*ones(1,3);            
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
            %fwdDic = DicUdHaarRec3();
            %adjDic = DicUdHaarDec3('NumLevels',nLevels);
            %gdnFcnG = PlgGdnSfth();
            %gdnFcnH = PlgGdnSfth();
            fwdDic = UdHaarSynthesis3dSystem();
            adjDic = UdHaarAnalysis3dSystem('NumberOfLevels',nlevels);
            gdnFcnG = GaussianDenoiserSfth();
            gdnFcnH = GaussianDenoiserSfth();
            
            reference  = PdsHsHcOct3(...
                'Observation',    vObs,...
                'PhiMode',        phimode,...
                'VRange',         vrange,...
                'MeasureProcess', coh3,...
                'Dictionary', { fwdDic, adjDic },...
                'GaussianDenoiser', { gdnFcnG, gdnFcnH } );

            target  = PdsHsHcOct3(...
                'Observation',    vObs,...
                'PhiMode',        phimode,...
                'VRange',         vrange,...
                'MeasureProcess', coh3,...
                'Dictionary', { fwdDic, adjDic },...
                'GaussianDenoiser', { gdnFcnG, gdnFcnH } ,...
                'SplitFactor',splitfactor,...
                'PadSize',padsize,...
                'UseParallel',useparallel);                
            
            % ��������
            for iter = 1:iterExpctd
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
        
         function testIsSizeCompensation(testCase,...
                depth,width,nlevels)
            
            % �p�����[�^
            phtm = phantom('Modified Shepp-Logan',depth);
            sliceYZ = permute(phtm,[1 3 2]);
            uSrc = 0.5*repmat(sliceYZ,[1 width 1]) + 1;
            barLambda = 1e-3;
            barEta    = 1e-3;
            
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
            import saivdr.dictionary.udhaar.*
            %fwdDic = DicUdHaarRec3();
            %adjDic = DicUdHaarDec3('NumLevels',nLevels);
            fwdDic = UdHaarSynthesis3dSystem();
            adjDic = UdHaarAnalysis3dSystem('NumberOfLevels',nlevels);
            coefs = adjDic.step(vObs);
            
            % �C���X�^���X����
            import saivdr.restoration.denoiser.*
            %gdnFcnG = PlgGdnSfth();
            %gdnFcnH = PlgGdnSfth();
            gdnFcnG = GaussianDenoiserSfth();
            gdnFcnH = GaussianDenoiserSfth();
            target  = PdsHsHcOct3(...
                'Lambda', barLambda,...
                'Eta',    barEta,...
                'Observation',    vObs,...
                'MeasureProcess', coh3,...
                'Dictionary', { fwdDic, adjDic },...
                'GaussianDenoiser', { gdnFcnG, gdnFcnH } );

            % ���Ғl
            lambdaExpctd = barLambda;
            etaExpctd    = barEta;

            % �]���i�ʏ�j
            target.step();
            lambdaActual = target.LambdaCompensated;
            etaActual    = target.EtaCompensated;

            %import matlab.unittest.constraints.IsLessThan
            testCase.verifyEqual(lambdaActual,lambdaExpctd)
            testCase.verifyEqual(etaActual,etaExpctd)

            % ���Ғl
            M = numel(vObs);
            L = numel(coefs);
            N = numel(uSrc);            
            lambdaExpctd = barLambda*M^2/L;
            etaExpctd    = barEta*M^2/N;            

            % �]���i�␳�j            
            target.release();
            target.IsSizeCompensation = true;
            target.step();
            lambdaActual = target.LambdaCompensated;
            etaActual    = target.EtaCompensated;            
            
            %import matlab.unittest.constraints.IsLessThan
            testCase.verifyEqual(lambdaActual,lambdaExpctd)
            testCase.verifyEqual(etaActual,etaExpctd)            
        end

        

    end
    
end