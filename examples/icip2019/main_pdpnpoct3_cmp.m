% �͈͐���t�� OCT �{�����[���f�[�^�����i��r�����p�V�~�����[�V�����j
%
% Reference:
%
% S. Ono, "Primal-dual plug-and-play image restoration,"
% IEEE Signal Processing Letters, vol.24, no.8, pp.1108-1112, Aug. 2017.
%
nTrials    = 5;

% �f�[�^�ۑ��t�H���_
dt = char(datetime('now','TimeZone','local','Format','d-MM-y-HH-mm-ssZ'));
targetdir = ['./data' dt];
if exist(targetdir,'dir') ~= 7
    mkdir(targetdir)
end

% �����p�����[�^
isVerbose  = false; % �O���t�\��

%% �œK���p�����[�^
maxIter = 1e+3;        % �ő�J�Ԃ���
vrange  = [-1.00 1.00]; % �n�[�h����
gamma1  = 1e-3;        % �X�e�b�v�T�C�Y

%% ��r�p�����[�^�ݒ�Z�b�g
dicSet = { 'idnt' }; % ����
gdnSet = { 'bm4d' }; % �K�E�X�f�m�C�U
levSet = { 1 };
awgSet = { 0.04 };  % �ϑ��m�C�Y
% eta = 0, vmin=-Inf, vmax=Inf �� ISTA����
lmdSet = num2cell(2.^(0:6)*1e-4); % �������p�����[�^ lambda (�ϊ��W���̃X�p�[�X���j

% ��r�p�����[�^��
nDics = length(dicSet);
nGdns = length(gdnSet);
nLevs = length(levSet);
nAwgs = length(awgSet);
nLmds = length(lmdSet);

nParamSet = nDics*nLevs*nLmds*nAwgs;

%% �ϑ��p�����[�^�ݒ�
pScale = 8.00; % �����x
pSigma = 8.00; % �L����
pFreq  = 0.25; % ���g��

%% ���M���f�[�^
depth   = 64;    % ���s
height  = depth; % ����
width   = 16; % ��
phtm    = phantom('Modified Shepp-Logan',depth);
sliceYZ = permute(phtm,[1 3 2]);
uSrc    = 0.5*repmat(sliceYZ,[1 width 1]) + 1;

%% �ϑ��ߒ�����
save([targetdir '/uSrc'],'uSrc')
phi  = RefractIdx2Reflect();
rSrc = phi.step(uSrc);
save([targetdir '/rsrc'],'rSrc')

msrProc = Coherence3(...
    'Scale',pScale,...
    'Sigma',pSigma,...
    'Frequency',pFreq);

%% �g���C�A��
paramSet   = cell(nParamSet,1);
volumeData = cell(nParamSet,1);

mymse = @(x,y) norm(x(:)-y(:),2)^2/numel(x);
mymse_ = cell(nParamSet,nTrials);
for iTrial = 1:nTrials
    
    idx = 1;
    for iAwg = 1:nAwgs
        wSigma = awgSet{iAwg};
        % ���˗��֐��͔���`
        vObs = msrProc.step(rSrc,'Forward') + wSigma*randn(size(rSrc));
        vobsname = [targetdir strrep(sprintf('/vobs_ref_wsigma%0.3e_trial%03d',...
            wSigma,iTrial),'.','_')];
        save(vobsname,'vObs');
        for iLmd = 1:nLmds
            lambda = lmdSet{iLmd};
            for iGdn = 1:nGdns
                gdn = gdnSet{iGdn};
                for iDic = 1:nDics
                    dic = dicSet{iDic};
                    for iLev = 1:nLevs
                        nLevels = levSet{iLev};
                        if ~(strcmp(dic,'idnt') && nLevels > 1)
                            paramSet{idx}.nLevels   = nLevels;
                            paramSet{idx}.wSigma    = wSigma;
                            paramSet{idx}.maxIter   = maxIter;
                            paramSet{idx}.gamma1    = gamma1;
                            paramSet{idx}.lambda    = lambda;
                            paramSet{idx}.gdn       = gdn;
                            paramSet{idx}.dic       = dic;
                            volumeData{idx}.vObs    = vObs;
                            idx = idx+1;
                        end
                    end
                end
            end
        end
    end
    
    nParamSet = idx-1;
    
    parsave = @(fname,x) save(fname,'x');
    parfor idx = 1:nParamSet
        lambda    = paramSet{idx}.lambda;
        nLevels   = paramSet{idx}.nLevels;
        gdn       = paramSet{idx}.gdn;
        dic       = paramSet{idx}.dic;
        %
        vObs      = volumeData{idx}.vObs;
        
        % Dictionary
        if strcmp(dic,'udht')
            import saivdr.dictionary.udhaar.*
            fwdDic = UdHaarSynthesis3dSystem();
            adjDic = UdHaarAnalysis3dSystem('NumberOfLevels',nLevels);
        elseif strcmp(dic,'idnt')
            import saivdr.dictionary.utility.*
            fwdDic = IdentitySynthesisSystem();
            adjDic = IdentityAnalysisSystem('IsVectorize',false);
        else
            error('DIC')
        end
        
        % Gaussian Denoiser
        if strcmp(gdn,'sfth')
            import saivdr.restoration.denoiser.*
            gdnFcnG = GaussianDenoiserSfth();
            gdnFcnH = GaussianDenoiserSfth();
        elseif strcmp(gdn,'bm4d')
            import saivdr.restoration.denoiser.*
            gdnFcnG = GaussianDenoiserBm4d();
            gdnFcnH = GaussianDenoiserSfth();
        else
            error('GDN')
        end
        
        % �ݒ����
        fname = strrep(...
            sprintf('dic%s_lev%d_gdn%s_lmd%0.3e_trial%03d',...
            dic,nLevels,gdn,lambda,iTrial),...
            '.','_');
        disp(fname)
        
        % �����X�e�b�v
        pdpnp = PdPnPOct3(...
            'Observation',    vObs,...
            'Lambda',         lambda,...
            'Gamma1',         gamma1,...
            'VRange',         vrange,...
            'MeasureProcess', msrProc,...
            'Dictionary',     { fwdDic, adjDic },...
            'GaussianDenoiser', gdnFcnG );
        disp(pdpnp)
        
        % ��������
        for itr = 1:maxIter
            rEst = pdpnp.step();
        end
        
        % ����f�[�^�ۑ�
        parsave([targetdir '/rEst_' fname ],rEst)
        
        % ���ʕۑ�
        mymse_{idx,iTrial} = mymse(rEst,rSrc);
    end
    
    %% �f�[�^�ۑ�
    save([targetdir '/results_cmp'],'mymse_','paramSet')
end