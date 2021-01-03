% �͈͐���t�� OCT �{�����[���f�[�^�����i�����j
%
% Reference:
%
% S. Ono, "Primal-dual plug-and-play image restoration,"
% IEEE Signal Processing Letters, vol.24, no.8, pp.1108-1112, Aug. 2017.
isCoin = false;

isVisible   = true;  % �O���t�\��
slicePlane  = 'YZ';  % �摜�X���C�X����
isIsta      = false; % ISTA
isNoDcShk   = false;  % DC����臒l���
%isEnvWght   = false;  % ����d�ݕt��
isVerbose   = true;

maxIter = 1000;
nLevels = 1;

obsScale = 20;
estScale = 40;

% method
method = 'udht';
%method = 'bm4d';

%%
dt = char(datetime('now','TimeZone','local','Format','d-MM-y-HH-mm-ssZ'));
targetdir = ['./exp' dt];
if exist(targetdir,'dir') ~= 7
    mkdir(targetdir)
end

%% �œK���p�����[�^
% eta = 0, vmin=-Inf, vmax=Inf �� ISTA����
lambda  = 1e-5; % �������p�����[�^ (�ϊ��W���̃X�p�[�X���j
eta     = 1e-1; % �������p�����[�^�i���s�����̑S�ϓ��j
vrange  = [1.00 1.50]; % �n�[�h���񉺌�
%
gamma1  = 1e-3; % �X�e�b�v�T�C�Y TODO �������m�F
%options.maxIter = 1e+3; % �ő�J�Ԃ���
%options.stopcri = 1e-9; % ��~����
% �ϑ����f���i���������̂݁j
% PHIMODE in { 'Linear', 'Signed-Quadratic', 'Reflection' }
phiMode   = 'Linear'; 
%phiMode   = 'Signed-Quadratic'; % ��1�������� 1e-7
%phiMode   = 'Reflection'; �@�@�@% ��1�������� 1e-30
%
% TODO ����`���f���͌��z�������ɂ�����悤�B��1�̐��䂪�K�v���B
%

%% �ϑ��p�����[�^�ݒ�
% ICIP2018
pScale = 1.00; % �����x
pSigma = 8.00; % �L����
pFreq  = 0.25; % ���g��
% SIP�V���|2017
%{
pScale = 1.00;
pSigma = 2.00;
pFrq   = 0.20;
%}
% ICASSP2018
%{
pScale = 1.00;
pSigma = 8.00;
pFrq   = 0.25;
%}

%% ���������i�p�[�Z�o���^�C�g�t���[���j�� �K�E�X�m�C�Y����
if strcmp(method,'udht')
    import saivdr.dictionary.udhaar.*
    import saivdr.restoration.denoiser.*
    fwdDic = UdHaarSynthesis3dSystem();
    adjDic = UdHaarAnalysis3dSystem('NumberOfLevels',nLevels);
    gdnFcnG = GaussianDenoiserSfth();
    gdnFcnH = GaussianDenoiserSfth();
elseif strcmp(method,'bm4d')
    import saivdr.dictionary.udhaar.*
    import saivdr.restoration.denoiser.*
    fwdDic = IdentitySynthesisSystem();
    adjDic = IdentityAnalysisSystem('IsVectorize',false);
    gdnFcnG = GaussianDenoiserBm4d();
    gdnFcnH = GaussianDenoiserSfth();
else
    error('METHOD')
end

%% �ϑ��f�[�^
if isCoin
    nSlices = 1211;
    cSlice  = 500;
    nSubSlices = 8;
    %nSubSlices = 512;
    sdir = '../0519_S0002coin�������p';
    sY = 201;
    eY = 440;
    sX = 181;
    eX = 420;
    adjScale  = 5e1;
else
    nSlices = 1673;
    cSlice  = 836;
    nSubSlices = 256;
    %nSubSlices = 1024;
    sY = 1;
    eY = 244;
    sX = 1;
    eX = 240;
    sdir = '../0519_S0007���̑������p';
    adjScale  = 1e2;
end

%% �f�[�^�ǂݍ���
finfo = imfinfo(sprintf('%s/k_C001H001S00010001.tif',sdir));
array3d = zeros(finfo.Height,finfo.Width,nSlices);
hw = waitbar(0,'Load data...');
for iSlice = 1:nSlices
    fname = sprintf('%s/k_C001H001S0001%04d.tif',sdir,iSlice);
    array3d(:,:,iSlice) = im2double(imread(fname));
    waitbar(iSlice/nSlices,hw);
end
close(hw)

%% ���s�����n�C�p�X�t�B���^
nLen = 21;
lpf = ones(nLen,1)/nLen;
lpf = permute(lpf,[2 3 1]);
array3d = array3d - imfilter(array3d,lpf,'circular');

%% �����Ώۂ̐؂�o��
nDim = size(array3d);
%vObs = array3d(sY:eY,sX:eX,cSlice-nSubSlices/2+1:cSlice+nSubSlices/2); % TODO: SUBVOLUME
limits = [sX eX sY eY (cSlice-nSubSlices/2+1) (cSlice+nSubSlices/2)];
vObs = subvolume(array3d,limits);
vObs = adjScale*vObs;
[height, width, depth] = size(vObs);
clear array3d

vobsname = [targetdir '/vobs'];
save(vobsname,'vObs');

%% �ϑ��ߒ�����
msrProc = Coherence3(...
    'Scale',pScale,...
    'Sigma',pSigma,...
    'Frequency',pFreq);

pKernel = msrProc.Kernel;
if isVisible
    figure(2)
    plot(squeeze(pKernel))
    xlabel('Depth')
    ylabel('Intensity')
    title('Coherence function P')
end

%% �ϑ��f�[�^�\��
if isVisible
    import saivdr.utility.*
    % ����
    hImg = figure(1);
    subplot(2,2,1)
    vdvobs = VolumetricDataVisualizer(...
        'Texture','3D',...
        'DAspect',[1 1 3],...
        'VRange',[-1 1],...
        'Scale',obsScale);    
    vdvobs.step(vObs);
    title(sprintf('Obs %s slice',slicePlane))
    %
    subplot(2,2,3)
    vdpobs = VolumetricDataPlot('Direction','Z','NumPlots',2);
    vdpobs.step(vObs,0*vObs);
    axis([0 size(vObs,3) -1 2])
    legend('Observation','Estimation','Location','best')
    title('Observation')
end

%% �����̕\��
if isVerbose
    disp('-------------------------------')    
    disp('�f�[�^�T�C�Y')
    disp('-------------------------------')            
    disp(['���~���~���s�@�@�@�F ' num2str(width) 'x' num2str(height) 'x' num2str(depth)])
    disp('-------------------------------')    
    disp('�ϑ��ߒ�')
    disp('-------------------------------')        
    disp(['�����x�@�@�@�@�@�@�F ' num2str(pScale)])
    disp(['�L����@�@�@�@�@�@�F ' num2str(pSigma)])
    disp(['���g���@�@�@�@�@�@�F ' num2str(pFreq)])   
end

%% Z����������o �� �Őݒ�
%{
if isEnvWght
    % �t�B���^�����O
    v = fwdProc(adjProc(vObs));

    % Z����������o
    env = fcn_env_z(v)/(sum(abs(pKernel(:))))^2;
    
    % ������
    env = imgaussfilt3(env,2);
    
    % �������p�����[�^�ŏd�ݐ���    
    emax = max(env(:));
    emin = min(env(:));    
    escales = ((emax-env)/(emax-emin));
    mscales = mean(escales(:));
    options.eta = options.eta * escales/mscales;
    if isVisible
        figure(3)
        widthV  = size(vObs,2);
        heightV = size(vObs,1);
        plot(squeeze(vObs(heightV/2,widthV/2,:)))
        xlabel('Depth')
        ylabel('Intensity')
        hold on
        plot(squeeze(env(heightV/2,widthV/2,:)))
        plot(squeeze(escales(heightV/2,widthV/2,:)))            
        legend('Observation','Envelope after P''P','Weight for \eta','best')
        title('Z-direction sequence a the vertical and horizontal center.')
        hold off
        
        figure(4)
        imshow(squeeze(escales(:,widthV/2,:)))
        title('Weight map for \eta. Y-Z slice at the horizontal center. ')
    end
end
%}

%% �f�[�^�������j�^�����O����
if isVisible
    vdv = VolumetricDataVisualizer(...
        'Texture','3D',...
        'DAspect',[1 1 3],...
        'VRange',[-1 1],...
        'Scale',estScale);    
    phiapx = RefractIdx2Reflect(...
        'PhiMode',phiMode,...
        'VRange', vrange);
    r = phiapx.step(vObs);
    %
    figure(hImg)
    subplot(2,2,2)
    vdv.step(r);
    hTitle2 = title('Rfl Est(  0)');
    %
    subplot(2,2,4)
    vdp = VolumetricDataPlot('Direction','Z','Scales',[1 10],'NumPlots',2);
    vdp.step(vObs,r);
    axis([0 size(vObs,3) -1 2])
    legend('Refraction Idx','Reflectance x10','Location','best')
    title('Restoration')
end

%% �����V�X�e������
pdshshc = PdsHsHcOct3(...
    'Observation',    vObs,...
    'Lambda',         lambda,...
    'Eta',            eta,...
    'Gamma1',         gamma1,...
    'PhiMode',        phiMode,...
    'VRange',         vrange,...
    'MeasureProcess', msrProc,...
    'Dictionary',     { fwdDic, adjDic },...
    'GaussianDenoiser', { gdnFcnG, gdnFcnH } );

disp(pdshshc)

%% ��������
for itr = 1:maxIter
    uEst = pdshshc.step();
    % Monitoring
    vdv.step(phiapx.step(uEst));
    vdpobs.step(vObs,msrProc(phiapx.step(uEst),'Forward'));
    vdp.step(uEst,phiapx.step(uEst));
    set(hTitle2,'String',sprintf('Rfl Est (%3d)',itr));
    %
    drawnow    
end

%% ���ʕ\��
rEst = phiapx.step(uEst);
fprintf('Restoration of Reflection\n');

%% ����f�[�^�ۑ�
if isCoin
    id = '0519_S0002';
else
    id = '0519_S0007';
end
save([targetdir '/uest_exp_' id ],'uEst')
save([targetdir '/rest_exp_' id ],'rEst')

%% �f�[�^�ۑ�
%save([targetdir '/results_exp_' id],'options')
