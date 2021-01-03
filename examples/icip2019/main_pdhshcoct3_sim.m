% �͈͐���t�� OCT �{�����[���f�[�^�����i�V�~�����[�V�����j
%
% Reference:
%
% S. Ono, "Primal-dual plug-and-play image restoration,"
% IEEE Signal Processing Letters, vol.24, no.8, pp.1108-1112, Aug. 2017.
%

% �����p�����[�^
isVisible  = true;  % �O���t�\��
isVerbose  = true;
slicePlane = 'YZ'; % �摜�X���C�X����
texture    = '2D';
obsScale   = 10;
estScale   = 20;

% �ϊ��p�����[�^
nLevels = 1;

% method
method = 'udht';
%method = 'bm4d';

%% �œK���p�����[�^
maxIter = 1e+3; % �ő�J�Ԃ���
%isNoDcShk   = false; % DC����臒l���
%isEnvWght   = false; % ����d�ݕt��
% eta = 0, vmin=-Inf, vmax=Inf �� ISTA����
if strcmp(method,'udht')
    lambda  = 1.6e-4; % �������p�����[�^ (�ϊ��W���̃X�p�[�X���j
    eta     = 0.8; % �������p�����[�^�i���s�����̑S�ϓ��j
elseif strcmp(method,'bm4d')
    lambda  = 1.6e-4; % �������p�����[�^ (�ϊ��W���̃X�p�[�X���j
    eta     = 0.8; % �������p�����[�^�i���s�����̑S�ϓ��j
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
wSigma = 4e-2; % �m�C�Y�W���΍�
pScale = 8.00; % �����x
pSigma = 8.00; % �L����
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
        'SlicePlane',slicePlane,...
        ...'DAspect',[1 1 3],...
        'VRange',[0 2]);
    subplot(2,3,1)
    vdvsrc.step(uSrc);
    xlabel(['Refract. Idx ' slicePlane ' slice'])
    %
    subplot(2,3,4)
    vdpsrc = VolumetricDataPlot(...
        'Direction','Z',...
        'NumPlots',2,...
        'Scales',[1 10]);
    vdpsrc.step(uSrc,phi.step(uSrc));
    axis([0 size(uSrc,3) -1 2])
    legend('Refraction Idx','Reflectance x10','Location','best')
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
        'SlicePlane',slicePlane,...
        ...'DAspect',[1 1 3],...
        'VRange',[-1 1],...
        'Scale',obsScale);    
    vdvobs.step(vObs);
    xlabel(sprintf('Obs %s slice: MSE = %6.4e',slicePlane,mymse(vObs,rSrc)))
    %
    import saivdr.utility.*
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
        'SlicePlane',slicePlane,...
        ...'DAspect',[1 1 3],...
        'VRange',[-1 1],...
        'Scale',estScale);    
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
        'Scales',[1 10]);
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
    set(hTitle3,'String',sprintf('Rfl Est (%3d): MSE = %6.4e',itr,mymse(phiapx.step(uEst),phi.step(uSrc))));
    %
    drawnow    
end

%% ���ʕ\��
rEst = phiapx.step(uEst);
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