% �͈͐���t�� OCT �{�����[���f�[�^�����i�����j
%
% Reference:
%
% S. Ono, "Primal-dual plug-and-play image restoration,"
% IEEE Signal Processing Letters, vol.24, no.8, pp.1108-1112, Aug. 2017.
%isCoin = false;

%% ����v�[���ݒ�
%%{
%poolobj = gcp('nocreate');
%delete(poolobj);
%nWorkers = 2;
%parpool(nWorkers)

%%  GPU �ݒ�
%spmd
%  gpuDevice( 1 + mod( labindex - 1, gpuDeviceCount ) )
%end
%%}

%% �ϊ��p�����[�^
nLevels = 1; % �c���[���x��
splitfactor = [2 2 20]; %2*ones(1,3);  % �����E�����E���s��������x
%splitfactor = [1 1 1]; %2*ones(1,3);  % �����E�����E���s��������x
padsize = 2^(nLevels-1)*ones(1,3); % OLS/OLA �p�b�h�T�C�Y
isintegritytest = false; % �������e�X�g
useparallel = false; % ����
usegpu = true; % GPU
issingle = true; % �P���x
method = 'udht';
%method = 'bm4d';
isNoDcShk   = false;  % DC����臒l���
%isEnvWght   = false;  % ����d�ݕt��

%% �ő�J��Ԃ���
maxIter = 1000;

%% �����p�����[�^
isVerbose  = true;
isVisible  = true;  % �O���t�\��
monint     = 50;    % ���j�^�����O�Ԋu
texture    = '2D';
slicePlane = 'YZ';  % �摜�X���C�X����
daspect    = [1 1 10];
isIsta     = false; % ISTA
obsScale = 20; % �ϑ��f�[�^�p���j�^�̋P�x����
estScale = 200; % �����f�[�^�p���j�^�̋P�x����
vdpScale = [1 10]; % �v���b�g�p�X�P�[������

%%
dt = char(datetime('now','TimeZone','local','Format','d-MM-y-HH-mm-ssZ'));
targetdir = ['./exp' dt];
if exist(targetdir,'dir') ~= 7
    mkdir(targetdir)
end

%% �œK���p�����[�^
% eta = 0, vmin=-Inf, vmax=Inf �� ISTA����
sizecomp = true; % �������p�����[�^�̃T�C�Y�␳
barlambda = 4e-12; % �������p�����[�^ (�ϊ��W���̃X�p�[�X���j
bareta    = 4e-9; % �������p�����[�^�i���s�����̑S�ϓ��j
vrange   = [1.00 1.50]; % �n�[�h���񉺌�
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
%
pScale = 8.00; % �����x
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
    adjDic = UdHaarAnalysis3dSystem('NumLevels',nLevels);
    gdnFcnG = GaussianDenoiserSfth();
    gdnFcnH = GaussianDenoiserSfth();
elseif strcmp(method,'bm4d')
    import saivdr.dictionary.utility.*
    import saivdr.restoration.denoiser.*
    fwdDic = IdentitySynthesisSystem();
    adjDic = IdentityAnalysisSystem('IsVectorize',false);
    gdnFcnG = GaussianDenoiserBm4d();
    gdnFcnH = GaussianDenoiserSfth();
else
    error('METHOD')
end

%% �ϑ��f�[�^
nSlices = 3000;
cSlice  = 1000;
%nSubSlices = 16;
nSubSlices = 2000;
sY = 1;
eY = 256;
sX = 1;
eX = 256;
sdir = '../LEXAR';
adjScale  = 5e-3;
%{
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
    %nSubSlices = 16;
    nSubSlices = 1600;
    sY = 1;
    eY = 244;
    sX = 1;
    eX = 240;
    sdir = '../0519_S0007���̑������p';
    adjScale  = 1e2;
end
%}

%% �f�[�^�ǂݍ���
data = fopen(sprintf('%s/oct0_C001H001S0001-00.mraw',sdir));
b=fread(data,'uint16');
nDims = [(eY-sY+1) (eX-sX+1) nSlices];
array3d = zeros(nDims);

hw = waitbar(0,'now reading and decording');
for i=1:nDims(1)
   for j=1000:nDims(3)
       array3d(i,:,j-1000+1) = b(1+(i-1)*nDims(2)+(j-1)*nDims(2)*nDims(1):i*nDims(2)+(j-1)*nDims(2)*nDims(1));
   end
   waitbar(i/nDims(1),hw)
end
close(hw)
%array3d = array3d/max(abs(array3d(:)));
%{
finfo = imfinfo(sprintf('%s/k_C001H001S00010001.tif',sdir));
array3d = zeros(finfo.Height,finfo.Width,nSlices);
hw = waitbar(0,'Load data...');
for iSlice = 1:nSlices
    fname = sprintf('%s/k_C001H001S0001%04d.tif',sdir,iSlice);
    array3d(:,:,iSlice) = im2double(imread(fname));
    waitbar(iSlice/nSlices,hw);
end
close(hw)
%}

%% ���s�����n�C�p�X�t�B���^
nLen = 21;
lpf = ones(nLen,1)/nLen;
lpf = permute(lpf,[2 3 1]);
%array3d = array3d - imfilter(array3d,lpf,'symmetric');

%% �����Ώۂ̐؂�o��
nDim = size(array3d);
%vObs = array3d(sY:eY,sX:eX,cSlice-nSubSlices/2+1:cSlice+nSubSlices/2); % TODO: SUBVOLUME
limits = [sX eX sY eY (cSlice-nSubSlices/2+1) (cSlice+nSubSlices/2)];
array3d = subvolume(array3d,limits);
vObs = array3d - imfilter(array3d,lpf,'symmetric');
vObs = adjScale*vObs;
[height, width, depth] = size(vObs);
clear array3d
if issingle
    vObs = single(vObs);
end

vobsname = [targetdir '/vobs'];
save(vobsname,'vObs');

%% �ϑ��ߒ�����
msrProc = Coherence3(...
    'Scale',pScale,...
    'Sigma',pSigma,...
    'Frequency',pFreq,...
    'UseGpu',usegpu);

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
        'Texture',texture,...
        'VRange',[-1 1],...
        'Scale',obsScale);    
    if strcmp(texture,'2D')
        vdvobs.SlicePlane = slicePlane;
        title(sprintf('Obs %s slice',slicePlane))
    else
        vdvobs.DAspect = daspect;
        title('Obs volume')
    end 
    vdvobs.step(vObs);

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
        'Texture',texture,...
        'VRange',[-1 1],...
        'Scale',estScale);    
    if strcmp(texture,'2D')
        vdv.SlicePlane = slicePlane;
    else
        vdv.DAspect = daspect;
    end
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
    vdp = VolumetricDataPlot('Direction','Z','Scales',vdpScale,'NumPlots',2);
    vdp.step(vObs,r);
    axis([0 size(vObs,3) -1 2])
    legend('Refraction Idx',['Reflectance x' num2str(vdpScale(2))],'Location','best')
    title('Restoration')
end

%% �����V�X�e������
pdshshc = PdsHsHcOct3(...
    'Observation',    vObs,...
    'Lambda',         barlambda,...
    'Eta',            bareta,...
    'IsSizeCompensation', sizecomp,...
    'Gamma1',         gamma1,...
    'PhiMode',        phiMode,...
    'VRange',         vrange,...
    'MeasureProcess', msrProc,...
    'Dictionary',     { fwdDic, adjDic },...
    'GaussianDenoiser', { gdnFcnG, gdnFcnH } ,...
    'SplitFactor',    splitfactor,...  % �����E�����E���s��������x
    'PadSize',        padsize,...
    'UseParallel',    useparallel,...
    'UseGpu',         usegpu,...
    'IsIntegrityTest', isintegritytest);

disp(pdshshc)

%% ��������
id = 'LEXAR';
%if isCoin
%    id = '0519_S0002';
%else
%    id = '0519_S0007';
%end
for itr = 1:maxIter
    tic
    uEst = pdshshc.step();
    if isVerbose && itr==1
        lambda = pdshshc.LambdaCompensated;
        eta   = pdshshc.EtaCompensated;
        disp(['lambda = ' num2str(lambda)]);
        disp(['eta    = ' num2str(eta)]);
    end
    % Monitoring
    if isVisible && (itr==1 || mod(itr,monint)==0)    
        rEst = phiapx.step(uEst);        
        vdv.step(rEst);
        vdpobs.step(vObs,msrProc((rEst),'Forward'));
        vdp.step(uEst,rEst);
        set(hTitle2,'String',sprintf('Rfl Est (%3d)',itr));
        save([targetdir '/uest_exp_' id '_' num2str(itr)],'uEst')
        save([targetdir '/rest_exp_' id '_' num2str(itr)],'rEst') 
        drawnow
    end
    toc
end
lambda = pdshshc.LambdaCompensated;
eta   = pdshshc.EtaCompensated;
disp(['lambda = ' num2str(lambda)]);
disp(['eta    = ' num2str(eta)]);

%% ����f�[�^�ۑ�

save([targetdir '/uest_exp_' id ],'uEst')
save([targetdir '/rest_exp_' id ],'rEst')

%% �f�[�^�ۑ�
options.method = method;
options.barlambda = barlambda;
options.bareta    = bareta;
options.lambda = lambda;
options.eta    = eta;
options.gamma1 = gamma1;
options.phiMode = phiMode;
options.vrange = vrange;
options.msrProc = msrProc;
options.fwdDic = fwdDic;
options.adjDic = adjDic;
options.gdnFcnG = gdnFcnG;
options.gdnFcnH = gdnFcnH;
save([targetdir '/results_exp_' id],'options')