% �͈͐���t�� OCT �{�����[���f�[�^�����i�V�~�����[�V�����j
%
% Reference:
%
% S. Ono, "Primal-dual plug-and-play image restoration,"
% IEEE Signal Processing Letters, vol.24, no.8, pp.1108-1112, Aug. 2017.
%

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
splitfactor = [1 1 1]; %2*ones(1,3);  % �����E�����E���s��������x
padsize = 2^(nLevels-1)*ones(1,3); % OLS/OLA �p�b�h�T�C�Y
isintegritytest = false; % �������e�X�g
useparallel = false; % ����
usegpu = true; % GPU
issingle = true; % �P���x
method = 'udht';
%method = 'bm4d';
isIsta      = false; % ISTA
isNoDcShk   = false;  % DC����臒l���
%isEnvWght   = false;  % ����d�ݕt��

%% �ő�J��Ԃ���
maxIter = 1000;

%% �����p�����[�^
isVerbose  = true;
isVisible  = true;  % �O���t�\��
monint     = 10;    % ���j�^�����O�Ԋu
texture    = '2D';
slicePlane = 'YZ';  % �摜�X���C�X����
daspect    = [1 1 3];
obsScale =  20; % �ϑ��f�[�^�p���j�^�̋P�x����
estScale = 200; % �����f�[�^�p���j�^�̋P�x����
vdpScale = [1 10]; % �v���b�g�p�X�P�[������

%% �œK���p�����[�^
% eta = 0, vmin=-Inf, vmax=Inf �� ISTA����
sizecomp = true; % �������p�����[�^�̃T�C�Y�␳
if strcmp(method,'udht')
    barlambda  = 1e-8; % �������p�����[�^ (�ϊ��W���̃X�p�[�X���j
    bareta     = 1e-8; % �������p�����[�^�i���s�����̑S�ϓ��j
elseif strcmp(method,'bm4d')
    barlambda  = 1e-8; % �������p�����[�^ (�ϊ��W���̃X�p�[�X���j
    bareta     = 1e-8; % �������p�����[�^�i���s�����̑S�ϓ��j
else
    error('METHOD')
end
vrange  = [1.00 1.50]; % �n�[�h����
gamma1  = 1e-3; % �X�e�b�v�T�C�Y TODO �������m�F
% �ϑ����f���i���������̂݁j
% PHIMODE in { 'Linear', 'Signed-Quadratic', 'Reflection' }
phiMode   = 'Linear';
%phiMode   = 'Signed-Quadratic'; % ��1�������� 1e-7
%phiMode   = 'Reflection'; �@�@�@% ��1�������� 1e-30
%
% TODO ����`���f���͌��z�������ɂ�����悤�B��1�̐��䂪�K�v���B
%

%% �ϑ��p�����[�^�ݒ�
wSigma = 1e-2; % �m�C�Y�W���΍�
pScale = 1.00; % �����x
pSigma = 4.00; % �L����
pFreq  = 0.25; % ���g��

%% ���������i�p�[�Z�o���^�C�g�t���[���j�� �K�E�X�m�C�Y����
if strcmp(method,'udht')
    import saivdr.dictionary.udhaar.*
    import saivdr.restoration.denoiser.*
    fwdDic = UdHaarSynthesis3dSystem();
    adjDic = UdHaarAnalysis3dSystem('NumberOfLevels',nLevels);
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

%% ���M���f�[�^����
depth   = 64; % ���s
height  = depth; % ����
width   = 16; % ��
phtm = phantom('Modified Shepp-Logan',depth);
sliceYZ = permute(phtm,[1 3 2]);
uSrc = 0.5*repmat(sliceYZ,[1 width 1]) + 1;

%% ���f�[�^�\��
if isVisible
    import saivdr.utility.*    
    phi = RefractIdx2Reflect();
    % ����
    %fsqzline = @(x) squeeze(x(floor(height/2),floor(width/2),:));
    %
    hImg = figure(1);
    %
    vdvsrc = VolumetricDataVisualizer(...
        'Texture',texture,...
        'VRange',[0 2]);
    if strcmp(texture,'2D')
        vdvsrc.SlicePlane = slicePlane;
    else
        vdvsrc.DAspect = daspect;
    end
        
    subplot(2,3,1)
    vdvsrc.step(uSrc);
    xlabel(['Refract. Idx ' slicePlane ' slice'])
    %
    subplot(2,3,4)
    vdpsrc = VolumetricDataPlot(...
        'Direction','Z',...
        'NumPlots',2,...
        'Scales',vdpScale);
    vdpsrc.step(uSrc,phi.step(uSrc));
    axis([0 size(uSrc,3) -1 2])
    legend('Refraction Idx',['Reflectance x' num2str(vdpScale(2))],'Location','best')
    title('Source')
end

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

%% �ϑ��f�[�^����
rng(0)
vObs = msrProc.step(phi.step(uSrc),'Forward') ...
    + wSigma*randn(size(uSrc));
% ���˗��֐��͔���`
if isVisible
    mymse = @(x,y) norm(x(:)-y(:),2)^2/numel(x);
    figure(hImg)
    subplot(2,3,2)
    rSrc = phi.step(uSrc);
    vdvobs = VolumetricDataVisualizer(...
        'Texture',texture,....
        'VRange',[-1 1],...
        'Scale',obsScale);    
    if strcmp(texture,'2D')
        vdvobs.SlicePlane = slicePlane;
    else
        vdvobs.DAspect = daspect;
    end
    vdvobs.step(vObs);
        
    xlabel(sprintf('Obs %s slice: MSE = %6.4e',slicePlane,mymse(vObs,rSrc)))
    %
    subplot(2,3,5)
    vdpobs = VolumetricDataPlot(...
        'Direction','Z',...
        'NumPlots',2);
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
    disp(['�m�C�Y�W���΍��@�@�F ' num2str(wSigma)])
end

%% Z����������o �� �Őݒ�
%{
if isEnvWght
    % �t�B���^�����O
    v = msrProc(msrProc(vObs,'Adjoint'),'Forward');
    
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
    subplot(2,3,3)
    vdv.step(r);
    hTitle3 = title(sprintf('Rfl Est(  0): MSE = %6.4e',...
        mymse(vObs,phi.step(uSrc))));
    %
    subplot(2,3,6)
    vdp = VolumetricDataPlot(...
        'Direction','Z',...
        'NumPlots',2,...
        'Scales',vdpScale);
    vdp.step(vObs,r);
    axis([0 size(vObs,3) -1 2])
    legend('Refraction Idx','Reflectance x10','Location','best')
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
    'GaussianDenoiser', { gdnFcnG, gdnFcnH },...
    'SplitFactor',    splitfactor,...
    'PadSize',        padsize,...
    'UseParallel',    useparallel,...
    'UseGpu',         usegpu,...
    'IsIntegrityTest', isintegritytest);

disp(pdshshc)

%% ��������
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
        set(hTitle3,'String',sprintf('Rfl Est (%3d): MSE = %6.4e',itr,mymse(rEst,phi.step(uSrc))));
        drawnow
    end
    toc
end
lamda = pdshshc.LambdaCompensated;
eta   = pdshshc.EtaCompensated;
disp(['lambda = ' num2str(lambda)]);
disp(['eta    = ' num2str(eta)]);

%% ���ʕ\��
rSrc = phi.step(uSrc);
fprintf('Restoration of Reflection: MSE = %6.4e\n',mymse(rEst,rSrc));

%%
dt = char(datetime('now','TimeZone','local','Format','d-MM-y-HH-mm-ssZ'));
targetdir = ['./sim_clg_' dt];
if exist(targetdir,'dir') ~= 7
    mkdir(targetdir)
end
save([targetdir '/uest_sim'],'uEst')
save([targetdir '/rest_sim'],'rEst')
save([targetdir '/usrc_sim'],'uSrc')
save([targetdir '/rsrc_sim'],'rSrc')
save([targetdir '/vobs_sim'],'vObs')

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
save([targetdir '/results_sim' ],'options') % TODO XML?