function M = essentialfactory(k)
% Returns a manifold structure to optimize over the space of essential
% matrices using the quotient representation.
% 
% function M = essentialfactory(k)
%
% 
% Quotient representation of the essential manifold: deals with the
% representation of the space of essential matrices M_rE. These are used in
% computer vision to represent the epipolar constraint between projected
% points in two perspective views.
%
% The space is represented as the quotient (SO(3)^2/SO(2)). See the
% following references for details
%
%   R. Tron, K. Daniilidis,
%   "On the quotient representation of the essential manifold"
%   IEEE Conference on Computer Vision and Pattern Recognition, 2014
%
% For computational purposes, each essential matrix is represented as a
% [3x6] matrix where each [3x3] block is a rotation.
% 
% The metric used is the one induced by the submersion of M_rE in SO(3)^2
%
% Tangent vectors are represented in the Lie algebra of SO(3)^2, i.e., as
% [3x6] matrices where each [3x3] block is a skew-symmetric matrix.
% Use the function tangent2ambient(X, H) to switch from the Lie algebra
% representation to the embedding space representation in R^(3x6).
%
% By default, k = 1.

% This file is part of Manopt: www.manopt.org.
% Original author: Roberto Tron, Aug. 8, 2014
% Contributors: 
    
    
    if ~exist('k', 'var') || isempty(k)
        k = 1; % BM: okay
    end
    
    if k == 1
        M.name = @() sprintf('Quotient representation of the essential manifold'); % BM: okay
    elseif k > 1
        M.name = @() sprintf('Product of %d quotient representations of the essential manifold', k); % BM: okay
    else
        error('k must be an integer no less than 1.'); % BM: okay
    end
    
    M.dim = k*5;% BM: okay
    
    M.inner = @(x, d1, d2) d1(:).'*d2(:); % BM: okay
    
    M.norm = @(x, d) norm(d(:)); % BM: okay
    
    M.typicaldist = @() pi*sqrt(2*k); % BM: okay
    
    M.proj = @tangentProjection; % BM: caution.. Uses sharp and vertproj, but no need to be as structs of M?
    function HProjHoriz=tangentProjection(X,H)
        %project H on the tangent space of SO(3)^2
        HProj = sharp(multiskew(multiprod(multitransp(flat(X)), flat(H)))); % BM: okay
        
        %compute projection on vertical component
        p = vertproj(X, HProj); % BM: okay

        HProjHoriz = HProj - multiprod(p/2,[hat3(permute(X(3,1:3,:),[2 3 1])) hat3(permute(X(3,4:6,:),[2 3 1]))]);% BM: okay
    end
    
     
    M.tangent = @(X, H) sharp(multiskew(flat(H))); % BM: okay
    
    M.egrad2rgrad=@egrad2rgrad;
    function rgrad = egrad2rgrad(X, egrad)
        % BM
        rgrad = M.proj(X, egrad);
    end 
    
    M.ehess2rhess = @ehess2rhess;
    function rhess = ehess2rhess(X, egrad, ehess, S)
        % BM code
        
        % Reminder : S contains skew-symmeric matrices. The actual
        % direction that the point X is moved along is X*S.
        RA=M.p1(X);
        RB=M.p2(X);
        SA=M.p1(S);
        SB=M.p2(S);
        
        G = egrad; %egrad(X);
        GA = M.p1(G);
        GB = M.p2(G);
        
        H = ehess; %ehess(X,dX);
        
        %The following is the vectorized version of connection=-[multisym(GA'*RA)*SA multisym(GB'*RB)*SB];
        connection = tangent2ambient(X,-cat(2,...
            multiprod(multisym(multiprod(multitransp(GA), RA)), SA),...
            multiprod(multisym(multiprod(multitransp(GB), RB)), SB)));
        
        rhess = M.proj(X,H + connection);
    end
    
    
    
    M.exp = @exponential;
    function Y = exponential(X, U, t)
        if nargin == 3
            U = t*U;
        end
        
        UFlat=flat(U);
        exptUFlat=rot3_exp(UFlat);
        Y = sharp(multiprod(flat(X), exptUFlat));
    end
    
    M.retr = @exponential;
    
    M.log = @logarithm; % BM:???
    function U = logarithm(X, Y, varargin)
        flagSigned=true;
        %optional parameters
        ivarargin=1;
        while(ivarargin<=length(varargin))
            switch(lower(varargin{ivarargin}))
                case 'signed'
                    flagSigned=true;
                case 'unsigned'
                    flagSigned=false;
                case 'flagsigned'
                    ivarargin=ivarargin+1;
                    flagSigned=varargin{ivarargin};
                otherwise
                        error(['Argument ' varargin{ivarargin} ' not valid!'])
            end
            ivarargin=ivarargin+1;
        end
        QX=[X(:,1:3,:);X(:,4:6,:)];
        QY=[Y(:,1:3,:);Y(:,4:6,:)];
        QYr=essential_closestRepresentative(QX,QY,'flagSigned',flagSigned);
        Yr=[QYr(1:3,:,:) QYr(4:6,:,:)];
        U=zeros(size(X));
        U(:,1:3,:)=rot3_log(multiprod(multitransp(X(:,1:3,:)),Yr(:,1:3,:)));
        U(:,4:6,:)=rot3_log(multiprod(multitransp(X(:,4:6,:)),Yr(:,4:6,:)));
    end

    M.hash = @(X) ['z' hashmd5(X(:))];
    
    M.rand = @() randessential(k);
    
    M.randvec = @randomvec;
    function U = randomvec(X)
        U = tangentProjection(X,sharp(randskew(3, 2*k)));
        U = U / sqrt(M.inner([],U,U));
    end
    
    M.lincomb = @lincomb;
    
    M.zerovec = @(x) zeros(3, 6, k);
    
    M.transp = @transport;
    function S2=transport(X1,X2,S1)
        %transport a vector from the tangent space at X1 to the tangent
        %space at X2. This transport uses the left translation of the
        %ambient group and preserves the norm of S1. The left translation
        %aligns the vertical spaces at the two elements.
        
        %group operation in the ambient group, X12=X2'*X1
        X12 = sharp(multiprod(multitransp(flat(X2)),flat(X1)));
        X12Flat = flat(X12);
        
        %left translation, S2=X12*S*X12'
        S2 = sharp(multiprod(X12Flat,multiprod(flat(S1),multitransp(X12Flat))));
    end
    
    M.pairmean = @pairmean;
    function Y = pairmean(X1, X2)
        V = M.log(X1, X2);
        Y = M.exp(X1, .5*V);
    end
    
    M.dist = @(x, y, varargin) M.norm(x, M.log(x, y, varargin{:}));
    
    M.vec = @(x, u_mat) u_mat(:);
    M.mat = @(x, u_vec) reshape(u_vec, [3, 6, k]);
    M.vecmatareisometries = @() true;
    
    
    %% Robertos functions
    M.p1 = @(X) X(:,1:3,:);
    M.p2 = @(X) X(:,4:6,:);
   

    function Hp = flat(H)
        %Reshape a [3x6xk] matrix to a [3x3x2k] matrix
        Hp=reshape(H,3,3,[]);
    end

    function H=sharp(Hp)
        %Reshape a [3x3x2k] matrix to a [3x6xk] matrix
        H=reshape(Hp,3,6,[]);
    end

   vertproj = @(X,H) multiprod(X(3,1:3,:),permute(vee3(H(:,1:3,:)),[1 3 2]))+multiprod(X(3,4:6,:),permute(vee3(H(:,4:6,:)),[1 3 2])); % BM: okay
    
   tangent2ambient = @(X, H) sharp(multiprod(flat(X), flat(H)));
	
  
end

% Linear combination of tangent vectors
function d = lincomb(x, a1, d1, a2, d2) %#ok<INUSL>

    if nargin == 3
        d = a1*d1;
    elseif nargin == 5
        d = a1*d1 + a2*d2;
    else
        error('Bad use of essential.lincomb.');
    end

end


% Some private calls
function v = vee3(V)
    v = squeeze([V(3,2,:)-V(2,3,:); V(1,3,:)-V(3,1,:); V(2,1,:)-V(1,2,:)])/2;
end


%Compute the exponential map in SO(3) using Rodrigues' formula
% function R=rot3_exp(V)
%V must be a [3x3xN] array of [3x3] skew-symmetric matrices.
function R=rot3_exp(V)
    v=vee3(V);
    nv=cnorm(v);
    idxZero=nv<1e-15;
    nvMod=nv;
    nvMod(idxZero)=1;
    
    vNorm=v./([1;1;1]*nvMod);
    
    %matrix exponential using Rodrigues' formula
    nv=shiftdim(nv,-1);
    c=cos(nv);
    s=sin(nv);
    [VNorm,vNormShift]=hat3(vNorm);
    vNormvNormT=multiprod(vNormShift,multitransp(vNormShift));
    R=multiprod(eye(3),c)+multiprod(VNorm,s)+multiprod(vNormvNormT,1-c);
end

%Compute the matrix representation of the cross product
%function [V,vShift]=hat3(v)
%V is a [3x3xN] array of skew-symmetric matrices where each [3x3] block is
%the matrix representation of the cross product of one of the columns of v
%vShift is equal to permute(v,[1 3 2]).
function [V,vShift]=hat3(v)
    N=size(v,2);
    V=zeros(3,3,N);
    vShift=permute(v,[1 3 2]);
    V(1,2,:)=-vShift(3,:,:);
    V(2,1,:)=vShift(3,:,:);
    V(1,3,:)=vShift(2,:,:);
    V(3,1,:)=-vShift(2,:,:);
    V(2,3,:)=-vShift(1,:,:);
    V(3,2,:)=vShift(1,:,:);
end

%Compute the logarithm map in SO(3)
% function V=rot3_log(R)
%V is a [3x3xN] array of [3x3] skew-symmetric matrices
function V=rot3_log(R)
    skewR=multiskew(R);
    ctheta=(multitrace(R)'-1)/2;
    stheta=cnorm(vee3(skewR));
    theta=atan2(stheta,ctheta);
    
    V=skewR;
    for ik=1:size(R,3)
        V(:,:,ik)=V(:,:,ik)/sincN(theta(ik));
    end
end

function Q = randessential(N)
        % Generates random essential matrices.
        %
        % function Q = randessential(N)
        %
        % Q is a [3x6] matrix where each [3x3] block is a uniformly distributed
        % matrix.
        
        % This file is part of Manopt: www.manopt.org.
        % Original author: Roberto Tron, Aug. 8, 2014
        % Contributors:
        % Change log:
        
        if nargin < 1
            N = 1;
        end
        
        Q = [randrot(3,N) randrot(3,N)];
        
end
    
function S = randskew(n, N)
% Generates random skew symmetric matrices with normal entries.
% 
% function S = randskew(n, N)
%
% S is an n-by-n-by-N matrix where each slice S(:, :, i) for i = 1..N is a
% random skew-symmetric matrix with upper triangular entries distributed
% independently following a normal distribution (Gaussian, zero mean, unit
% variance).
%
% See also: randrot

% This file is part of Manopt: www.manopt.org.
% Original author: Nicolas Boumal, Sept. 25, 2012.
% Contributors: 
% Change log: 


    if nargin < 2
        N = 1;
    end

    % Subindices of the (strictly) upper triangular entries of an n-by-n
    % matrix
    [I J] = find(triu(ones(n), 1));
    
    K = repmat(1:N, n*(n-1)/2, 1);
    
    % Indices of the strictly upper triangular entries of all N slices of
    % an n-by-n-by-N matrix
    L = sub2ind([n n N], repmat(I, N, 1), repmat(J, N, 1), K(:));
    
    % Allocate memory for N random skew matrices of size n-by-n and
    % populate each upper triangular entry with a random number following a
    % normal distribution and copy them with opposite sign on the
    % corresponding lower triangular side.
    S = zeros(n, n, N);
    S(L) = randn(size(L));
    S = S-multitransp(S);

end

function sx=sincN(x)
    sx=sin(x)./x;
    sx(x==0)=1;
end

function nv=cnorm(v)
    nv=sqrt(sum(v.^2));
end