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

%
method = 'bm4d';

%% �œK���p�����[�^
maxIter = 1e+3; % �ő�J�Ԃ���
%isNoDcShk   = false; % DC����臒l���
%isEnvWght   = false; % ����d�ݕt��
% eta = 0, vmin=-Inf, vmax=Inf �� ISTA����
lambda  = 8e-4; %0.0032; % �������p�����[�^ 
vrange  = [-1.00 1.00]; % �n�[�h����
gamma1  = 1e-3; % �X�e�b�v�T�C�Y TODO �������m�F
%

%% �ϑ��p�����[�^�ݒ�
wSigma = 1e-2; % �m�C�Y�W���΍�
pScale = 1.00; % �����x
pSigma = 4.00; % �L����
pFreq  = 0.25; % ���g��

%% ���������i�p�[�Z�o���^�C�g�t���[���j
import saivdr.dictionary.utility.*
fwdDic = IdentitySynthesisSystem();
adjDic = IdentityAnalysisSystem('IsVectorize',false);

%% �K�E�X�m�C�Y����
import saivdr.restoration.denoiser.*
gdnFcnG = GaussianDenoiserBm4d();

%% ���M���f�[�^����
depth   = 64; % ���s
height  = depth; % ����
width   = 16; % ��
phtm = phantom('Modified Shepp-Logan',depth);
sliceYZ = permute(phtm,[1 3 2]);
uSrc = 0.5*repmat(sliceYZ,[1 width 1]) + 1;
phi = RefractIdx2Reflect();
rSrc = phi.step(uSrc);

%% ���f�[�^�\��
if isVisible
    import saivdr.utility.*
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
    vdpsrc.step(uSrc,rSrc);
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
vObs = msrProc.step(rSrc,'Forward') ...
    + wSigma*randn(size(rSrc));
% ���˗��֐��͔���`
if isVisible
    mymse = @(x,y) norm(x(:)-y(:),2)^2/numel(x);
    figure(hImg)
    subplot(2,3,2)
    vdvobs = VolumetricDataVisualizer(...
        'Texture',texture,....
        'SlicePlane',slicePlane,...
        ...'DAspect',[1 1 3],...
        'VRange',[-1 1],...
        'Scale',obsScale);    
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


%% �f�[�^�������j�^�����O����
if isVisible
    vdv = VolumetricDataVisualizer(...
        'Texture',texture,...
        'SlicePlane',slicePlane,...
        ...'DAspect',[1 1 3],...
        'VRange',[-1 1],...
        'Scale',estScale);    
    r = vObs;
    %
    figure(hImg)
    subplot(2,3,3)
    vdv.step(r);
    hTitle3 = title(sprintf('Rfl Est(  0): MSE = %6.4e',...
        mymse(vObs,rSrc)));
    %
    subplot(2,3,6)
    vdp = VolumetricDataPlot(...
        'Direction','Z',...
        'NumPlots',1,...
        'Scales',10);
    vdp.step(r);
    axis([0 size(vObs,3) -1 2])
    legend('Reflectance x10','Location','best')
    title('Restoration')
end

%% �����V�X�e������
pdpnp = PdPnPOct3(...
    'Observation',    vObs,...
    'Lambda',         lambda,...
    'Gamma1',         gamma1,...
    'VRange',         vrange,...
    'MeasureProcess', msrProc,...
    'Dictionary',     { fwdDic, adjDic },...
    'GaussianDenoiser', gdnFcnG );

disp(pdpnp)

%% ��������
for itr = 1:maxIter
    rEst = pdpnp.step();
    % Monitoring
    vdpobs.step(vObs,msrProc(rEst,'Forward'));
    vdp.step(rEst);
    vdv.step(rEst);
    set(hTitle3,'String',sprintf('Rfl Est (%3d): MSE = %6.4e',itr,mymse(rEst,rSrc)));
    %
    drawnow    
end

%% ���ʕ\��
fprintf('Restoration of Reflection: MSE = %6.4e\n',mymse(rEst,rSrc));

%%
dt = char(datetime('now','TimeZone','local','Format','d-MM-y-HH-mm-ssZ'));
targetdir = ['./sim_clg_' dt];
if exist(targetdir,'dir') ~= 7
    mkdir(targetdir)
end
save([targetdir '/usrc_sim'],'uSrc')
save([targetdir '/rest_sim'],'rEst')
save([targetdir '/rsrc_sim'],'rSrc')
save([targetdir '/vobs_sim'],'vObs')

%% �f�[�^�ۑ�
options.method = method;
options.lambda = lambda;
options.gamma1 = gamma1;
options.vrange = vrange;
options.msrProc = msrProc;
options.fwdDic = fwdDic;
options.adjDic = adjDic;
options.gdnFcnG = gdnFcnG;
save([targetdir '/results_sim' ],'options') % TODO XML?