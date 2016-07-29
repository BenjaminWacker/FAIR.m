% (c) Jan Modersitzki 2010/12/27, see FAIR.2 and FAIRcopyright.m.
% http://www.mic.uni-luebeck.de/people/jan-modersitzki.html
%
% function [Tc,dT] = linearInterSmooth(T,omega,x,varargin);
%
% smoothed linear interpolator for the data T given on a cell-centered grid 
% on omega, to be evaluated at x
% 
% In contrast to an linear interpolantion, an approaximation is computed;
% this approximation is identical to the linear interpolant but replaced 
% by a quadratic in in a small eta neighborhood of each interpolation knot, 
% such that the approximation is globally differentiable;
% approximation for the data T given on a cell-centered grid evaluated at x
% version 2015/05/20

function [Tc,dT] = linearInterSmooth(T,omega,x,varargin)

Tc = mfilename('fullpath'); dT = []; 

if nargin == 0, 
  runMinimalExample;
  return;
elseif nargin == 1 && isempty(T),
  return;
end;

% flag for computing the derivative
doDerivative = (nargout>1);
matrixFree   = 0;
for k=1:2:length(varargin), % overwrite default parameter
  eval([varargin{k},'=varargin{',int2str(k+1),'};']);
end;

% get data size m, cell size h, dimension d, and number n of interpolation points
dim = length(omega)/2;
m   = size(T);         if dim == 1, m = numel(T); end;
h   = (omega(2:2:end)-omega(1:2:end))./m;
n   = length(x)/dim;

switch dim,
  case 1, [Tc,dT] = linearInterSmooth1D(T,omega,x,doDerivative,varargin{:});
  case 2, [Tc,dT] = linearInterSmooth2D(T,omega,x,doDerivative,varargin{:});
  case 3, [Tc,dT] = linearInterSmooth3D(T,omega,x,doDerivative,varargin{:});
end;
if doDerivative
  for i=1:dim, dT(:,i) = dT(:,i)/h(i); end
  if not(matrixFree)
    dT = spdiags(dT,n*(0:(dim-1)),n,dim*n);
  end
end

% ===================================================================================
function [Tc,dT] = linearInterSmooth1D(T,omega,x,doDerivative,varargin)

eta = 0.1;
for k=1:2:length(varargin), % overwrite default parameter
  eval([varargin{k},'=varargin{',int2str(k+1),'};']);
end;

% get data size m, cell size h, dimension d, and number n of interpolation points
m  = length(T); 
h  = (omega(2:2:end)-omega(1:2:end))./m; 
d  = length(omega)/2; 
n  = length(x)/d;    
x  = reshape(x,n,d);
% map x from [h/2,omega-h/2] -> [1,m],
for i=1:d, x(:,i) = (x(:,i)-omega(2*i-1))/h(i) + 0.5; end;

Tc = zeros(n,1); dT = [];                 % initialize output
if doDerivative, dT = zeros(n,1);  end;

valid = find( 0<x & x<m(1)+1 );           % find valid points
if isempty(valid), 
  if doDerivative,  dT = sparse(n,n);  end;
  return; 
end;

pad = 2;                                  % padding to reduce cases  
To = zeros(m+2*pad,1);
To(pad+(1:m)) = reshape(T,m,1);

% linear part
p = floor(x(valid)); xi = x(valid) - p;   % split x into integer/remainder
p = pad+p;                                % add the pad
I = find(xi>eta & xi<(1-eta) );
validI = valid(I); pI = p(I); xiI = xi(I);
Tc(validI) = To(pI).* (1-xiI) + To(pI+1).*xiI; % compute weighted sum
if doDerivative
    dT(validI) = To(pI+1)-To(pI);
end

% in eta
p = round(x(valid)); xi = x(valid)-p;      
p = pad+p;
I = find(abs(xi)<=eta);
validI = valid(I); pI = p(I); xiI = xi(I);

Tc(validI)=To(pI)+(To(pI)-To(pI-1)).*xiI...
              +1/(2*eta)*(1/2*To(pI-1)-To(pI)+1/2*To(pI+1)).*(xiI+eta).^2;
if doDerivative 
    dT(validI) = To(pI)-To(pI-1)+1/eta*(1/2*To(pI-1)-To(pI)+1/2*To(pI+1)).*(xiI+eta);
end

% ===================================================================================
function [Tc,dT] = linearInterSmooth2D(T,omega,x,doDerivative,varargin)

eta = 0.1;
for k=1:2:length(varargin), % overwrite default parameter
  eval([varargin{k},'=varargin{',int2str(k+1),'};']);
end;

% get data size m, cell size h, dimension d, and number n of interpolation points
m  = size(T); 
h  = (omega(2:2:end)-omega(1:2:end))./m; 
d  = length(omega)/2; 
n  = length(x)/d;    
x  = reshape(x,n,d);
% map x from [h/2,omega-h/2] -> [1,m],
for i=1:d, x(:,i) = (x(:,i)-omega(2*i-1))/h(i) + 0.5; end;

Tc = zeros(n,1); dT = [];       % initialize output
if doDerivative, dT = zeros(n,d);  end;

% find valid points Testen, ob aus B
valid  = find( -eta<x(:,1) & x(:,1)<m(1)+1+eta ...
                & -eta<x(:,2) & x(:,2)<m(2)+1+eta );

if isempty(valid), 
  if doDerivative,  dT = sparse(n,d*n);  end;
  return; 
end;

% padding to reduce cases  
pad = 2;                                
To = zeros(m+2*pad);
To(pad+(1:m(1)),pad+(1:m(2))) = T;

% in the following we will deal with 4 cases
% first case:  no component in eta: linear interpolation
% second case: x1 in eta, x2 not in eta
% third case:  x2 in eta, x1 not in eta
% fourth case: x1 and x2 in eta

%   considered cases
%
%       |   |           |   |           |   |
%   --------------------------------------------
%       |   |           |   |           |   |
%   --------------------------------------------
%       |   |           |   |           |   |
%       |   |           | 2 |     1     |   |
%       |   |           |   |           |   |
%   --------------------------------------------
%       |   |           | 4 |     3     |   |
%   --------------------------------------------
%       |   |           |   |           |   |
%       |   |           |   |           |   |
%       |   |           |   |           |   |
%   --------------------------------------------
%       |   |           |   |           |   |
%   --------------------------------------------
%       |   |           |   |           |   |

% -------------------------------------------------------------------------
% linear part (case 1)
% -------------------------------------------------------------------------
% split x into integer/remainder
P = floor(x(valid,:)); P2 = round(x(valid,:)); 
X2=x(valid,:)-P2; x=x(valid,:)-P;

% increments for linearized ordering
i1 = 1;                                  
i2 = size(To,1);              
p  = (pad + P(:,1)) + i2*(P(:,2)+pad-1);

% xi1 and xi2 not in eta
I = find(x(:,1)>eta & x(:,1)<(1-eta) & x(:,2)>eta & x(:,2)<(1-eta) );

% no components in eta --> 2D linear interpolation 
Tc(valid(I)) = (To(p(I)).*(1-x(I,1))+To(p(I)+i1).*x(I,1)).*(1-x(I,2))...
                +(To(p(I)+i2).*(1-x(I,1))+ To(p(I)+i1+i2).*x(I,1)).*x(I,2);
% compute derivative, if necessary 
if doDerivative
    dT(valid(I),1) = (To(p(I)+i1)-To(p(I))).*(1-x(I,2))...
                    +(To(p(I)+i1+i2)-To(p(I)+i2)).*x(I,2);
    dT(valid(I),2) = (To(p(I)+i2)-To(p(I))).*(1-x(I,1))...
                    +(To(p(I)+i1+i2)-To(p(I)+i1)).*x(I,1);
end

% -------------------------------------------------------------------------
% quadratic part (case 2,3,4)
% -------------------------------------------------------------------------

% idea for case 2,3:
% we need 3 points for the quadratic interpolation in needed direction
% This points can be computed via linear interpolation, 
% because they are not in eta

% second case
% xi1 in eta and xi2 not in eta
I = find((x(:,1)<=eta |x(:,1) >=(1-eta))& x(:,2)>eta & x(:,2)<(1-eta));
p  = (pad + P2(:,1)) + i2*(P(:,2)+pad-1);

% compute necessary 3 points for quadratic interpolation
% via linear interpolation in xi2-direction
temp = x(I,[2,2,2])...
        .*([To(p(I)+i2-i1),To(p(I)+i2),To(p(I)+i2+i1)]...
        -[To(p(I)-i1),To(p(I)),To(p(I)+i1)])...
        +[To(p(I)-i1),To(p(I)),To(p(I)+i1)];

% quadratic interpolation in xi1-direction
Tc(valid(I))=temp(:,2)+(temp(:,3)-temp(:,2)).*X2(I,1)...
            +1/(4*eta)*(temp(:,3)-2*temp(:,2)+temp(:,1)).*(X2(I,1)-eta).^2;
% compute derivative, if necessary 
if doDerivative
     dT(valid(I),1) = (temp(:,3)-temp(:,2))...
                       +1/(2*eta)*(temp(:,3)-2*temp(:,2)...
                       +temp(:,1)).*(X2(I,1)-eta);
     dT(valid(I),2) = (To(p(I)+i2)-To(p(I)))...
                        .*(1-X2(I,1)-1/(2*eta)*((X2(I,1)-eta).^2))...
                        +(To(p(I)+i2+i1)-To(p(I)+i1))...
                            .*(X2(I,1)+1/(4*eta)*((X2(I,1)-eta).^2))...
                        +(To(p(I)+i2-i1)-To(p(I)-i1))...
                            .*(1/(4*eta)*((X2(I,1)-eta).^2));
end

% third case
% xi1 not in eta, xi2 in eta
I = find((x(:,2)<=eta |x(:,2) >=(1-eta))& x(:,1)>eta & x(:,1)<(1-eta));
p  = (pad + P(:,1)) + i2*(P2(:,2)+pad-1);

%compute necessary 3 points for quadratic interpolation
% via linear interpolation in xi1-direction
temp = x(I,[1,1,1])...
            .*([To(p(I)-i2+i1),To(p(I)+i1),To(p(I)+i2+i1)]...
        -[To(p(I)-i2),To(p(I)),To(p(I)+i2)])...
        +[To(p(I)-i2),To(p(I)),To(p(I)+i2)];
% quadratic interpolation in xi2-direction
Tc(valid(I))=temp(:,2)+(temp(:,3)-temp(:,2)).*X2(I,2)...
            +1/(4*eta)*(temp(:,3)-2*temp(:,2)+temp(:,1)).*(X2(I,2)-eta).^2;
% compute derivative, if necessary 
if doDerivative
     dT(valid(I),1) = (To(p(I)-i2+i1)-To(p(I)-i2))...
                        .*(1/(4*eta)*((X2(I,2)-eta).^2))...
                      +(To(p(I)+i1)-To(p(I)))...
                        .*(1-X2(I,2)-1/(2*eta).*((X2(I,2)-eta).^2))...
                      +(To(p(I)+i2+i1)-To(p(I)+i2))...
                        .*(X2(I,2)+1/(4*eta).*((X2(I,2)-eta).^2));                      
     dT(valid(I),2) = (temp(:,3)-temp(:,2))...
                        +1/(2*eta)*(temp(:,3)...
                        -2*temp(:,2)+temp(:,1)).*(X2(I,2)-eta);
end

% fourth case
% idea: it is nearly the same idea as in both prior cases 
% we need to compute the 3 points in one direction to do a 
% quadratic interpolation in the other direction but in this case
% we have to do this via quadratic interpolation, too.

% xi1 and xi2 in eta
I = find((x(:,1)<=eta & x(:,2)<=eta) | (x(:,1)>=(1-eta) & x(:,2)<=eta)...
        | (x(:,1)<=eta & x(:,2)>=(1-eta)) ...
        | (x(:,1)>=(1-eta) & x(:,2)>=(1-eta)) );
    
p  = (pad + P2(:,1)) + i2*(P2(:,2)+pad-1);

%compute necessary 3 points quadratic interpolation
% via quadratic interpolation in xi2-direction
temp = [To(p(I)-i1),To(p(I)),To(p(I)+i1)]...
        +([To(p(I)-i1+i2),To(p(I)+i2),To(p(I)+i1+i2)]...
        -[To(p(I)-i1),To(p(I)),To(p(I)+i1)])...
            .*[X2(I,2),X2(I,2),X2(I,2)]...
        +1/(4*eta)*([To(p(I)-i1+i2),To(p(I)+i2),To(p(I)+i1+i2)]...
        -2*[To(p(I)-i1),To(p(I)),To(p(I)+i1)]...
        +[To(p(I)-i1-i2),To(p(I)-i2),To(p(I)+i1-i2)])...
            .*([X2(I,2),X2(I,2),X2(I,2)]-eta).^2;

%  quadratic interpolation in xi1-direction
Tc(valid(I))=temp(:,2)+(temp(:,3)-temp(:,2)).*X2(I,1)...
              +1/(4*eta)*(temp(:,3)-2*temp(:,2)+temp(:,1))...
                .*(X2(I,1)-eta).^2;
% compute derivative, if necessary 
if doDerivative
     dT(valid(I),1) = (temp(:,3)-temp(:,2))...
                      +1/(2*eta)*(temp(:,3)-2*temp(:,2)+temp(:,1))...
                        .*(X2(I,1)-eta);
     dT(valid(I),2) = (To(p(I)-i1+i2)-To(p(I)-i1)+1/(2*eta)...
                      *(To(p(I)-i1+i2)-2*To(p(I)-i1)+To(p(I)-i1-i2))...
                        .*(X2(I,2)-eta)).*(1/(4*eta)*((X2(I,1)-eta).^2))...
                      +(To(p(I)+i2)-To(p(I))+1/(2*eta)...
                      *(To(p(I)+i2)-2*To(p(I))+To(p(I)-i2))...
                        .*(X2(I,2)-eta)).*(1-X2(I,1)-1/(2*eta)...
                        .*((X2(I,1)-eta).^2))...
                      +(To(p(I)+i1+i2)-To(p(I)+i1)+1/(2*eta)...
                      *(To(p(I)+i1+i2)-2*To(p(I)+i1)+To(p(I)+i1-i2))...
                        .*(X2(I,2)-eta)).*(X2(I,1)...
                        +1/(4*eta).*((X2(I,1)-eta).^2));
end
    
% ===================================================================================
function [Tc,dT] = linearInterSmooth3D(T,omega,x,doDerivative,varargin)

eta = 0.1;
for k=1:2:length(varargin), % overwrite default parameter
  eval([varargin{k},'=varargin{',int2str(k+1),'};']);
end;

% get data size m, cell size h, dimension d, and number n of interpolation points
m  = size(T); 
h  = (omega(2:2:end)-omega(1:2:end))./m; 
d  = length(omega)/2; 
n  = length(x)/d;    
x  = reshape(x,n,d);
% map x from [h/2,omega-h/2] -> [1,m],
for i=1:d, x(:,i) = (x(:,i)-omega(2*i-1))/h(i) + 0.5; end;

Tc = zeros(n,1); dT = [];       % initialize output
if doDerivative, dT = zeros(n,d);  end;

% find valid points Testen, ob aus B
valid  = find( -eta<x(:,1) & x(:,1)<m(1)+1+eta ...
                & -eta<x(:,2) & x(:,2)<m(2)+1+eta ...
                & -eta<x(:,3) & x(:,3)<m(3)+1+eta);

if isempty(valid), 
  if doDerivative,  dT = sparse(n,d*n);  end;
  return; 
end;

% padding to reduce cases  
pad = 2;                                
To = zeros(m+2*pad);
To(pad+(1:m(1)),pad+(1:m(2)),pad+(1:m(3))) = T;

% split x into integer/remainder
P = floor(x(valid,:)); P2 = round(x(valid,:)); 
X2=x(valid,:)-P2; x=x(valid,:)-P;

% increments for linearized ordering
i1 = 1; i2 = size(To,1); i3 = size(To,1)*size(To,2);
p  = (pad + P(:,1)) + i2*(pad + P(:,2) - 1) + i3*(pad + P(:,3) -1);

% -------------------------------------------------------------------------
% computation
% -------------------------------------------------------------------------
% in the following we will deal with 4 main cases
% first case:  no compenent in eta: linear interpolation
% second case: exactly one component in eta
% third case:  exactly two components in eta
% fourth case: all components in eta
% the second and third case are both divided in 3 more cases concerning 
% the possible combinations of the components

% first case: no component in eta
I = find(x(:,1)>eta & x(:,1)<(1-eta) & x(:,2)>eta...
       & x(:,2)<(1-eta) & x(:,3)>eta & x(:,3)<(1-eta) );

% no component in eta --> 3D linear interpolation
Tc(valid(I)) = ((To(p(I)).*(1-x(I,1))+To(p(I)+i1).*x(I,1)).*(1-x(I,2))...
  +(To(p(I)+i2).*(1-x(I,1))+To(p(I)+i1+i2).*x(I,1)).*(x(I,2))).*(1-x(I,3)) ...
  +((To(p(I)+i3).*(1-x(I,1))+To(p(I)+i1+i3).*x(I,1)).*(1-x(I,2)) ...
  +(To(p(I)+i2+i3).*(1-x(I,1))+To(p(I)+i1+i2+i3).*x(I,1)).*(x(I,2))).*(x(I,3));

% compute derivative, if necessary
if doDerivative 
    dT(valid(I),1) = ((To(p(I)+i1)-To(p(I))).*(1-x(I,2))...
        +(To(p(I)+i1+i2)-To(p(I)+i2)).*x(I,2)).*(1-x(I,3)) ...
        +((To(p(I)+i1+i3)-To(p(I)+i3)).*(1-x(I,2))...
        +(To(p(I)+i1+i2+i3)-To(p(I)+i2+i3)).*x(I,2)).*(x(I,3));
    dT(valid(I),2) = ((To(p(I)+i2)-To(p(I))).*(1-x(I,1))...
        +(To(p(I)+i1+i2)-To(p(I)+i1)).*x(I,1)).*(1-x(I,3)) ...
        +((To(p(I)+i2+i3)-To(p(I)+i3)).*(1-x(I,1))...
        +(To(p(I)+i1+i2+i3)-To(p(I)+i1+i3)).*x(I,1)).*(x(I,3));
    dT(valid(I),3) = ((To(p(I)+i3).*(1-x(I,1))...
        +To(p(I)+i1+i3).*x(I,1)).*(1-x(I,2)) ...
        +(To(p(I)+i2+i3).*(1-x(I,1))...
        +To(p(I)+i1+i2+i3).*x(I,1)).*(x(I,2))) ....
        -((To(p(I)).*(1-x(I,1))+To(p(I)+i1).*x(I,1)).*(1-x(I,2)) ...
        +(To(p(I)+i2).*(1-x(I,1))+To(p(I)+i1+i2).*x(I,1)).*(x(I,2)));
end

% --- quadratic part ------------------------------------------------------
% 
% 
% second case: exactly one direction in eta
% there are three cases
% case A: x3 in eta  -  x1,x2 not in eta
% case B: x1 in eta  -  x2,x3 not in eta
% case C: x2 in eta  -  x1,x3 not in eta
% idea: compute 3 points via 2D linear interpolation on parallel planes
% then quadratic interpolation in the third direction (component in eta)

% case A: x3 in eta  -  x1,x2 not
I = find(x(:,1)>eta & x(:,1)<(1-eta) & x(:,2)>eta & x(:,2)<(1-eta)...
      & (x(:,3)<=eta | x(:,3)>=(1-eta)) );
p  = (pad + P(:,1)) + i2*(pad + P(:,2) - 1) + i3*(pad + P2(:,3) -1);

% linear interpolation on three parallel planes (x1,x2)
temp = ([To(p(I)-i3), To(p(I)), To(p(I)+i3)].*(1-x(I,[1,1,1]))...
    +[To(p(I)+i1-i3), To(p(I)+i1), To(p(I)+i1+i3)]...
    .*x(I,[1,1,1])).*(1-x(I,[2,2,2]))...
    +([To(p(I)+i2-i3), To(p(I)+i2), To(p(I)+i2+i3)].*(1-x(I,[1,1,1]))...
    +[To(p(I)+i1+i2-i3),To(p(I)+i1+i2),To(p(I)+i1+i2+i3)]...
    .*x(I,[1,1,1])).*x(I,[2,2,2]);  
% quadratic interpolation in x3-direction
Tc(valid(I))=temp(:,2)+(temp(:,3)-temp(:,2)).*X2(I,3)...
            +1/(4*eta)*(temp(:,3)-2*temp(:,2)+temp(:,1)).*(X2(I,3)-eta).^2;            
% compute derivative, if necessary
if doDerivative
    dT(valid(I),3)= (temp(:,3)-temp(:,2)) ... 
        +1/(2*eta)*(temp(:,3)-2*temp(:,2)+temp(:,1)).*(X2(I,3)-eta);            
    % dtemp/dx1
    temp = ([To(p(I)+i1-i3), To(p(I)+i1), To(p(I)+i1+i3)]...
        -[To(p(I)-i3), To(p(I)), To(p(I)+i3)]).*(1-x(I,[2,2,2]))...
        +([To(p(I)+i1+i2-i3),To(p(I)+i1+i2),To(p(I)+i1+i2+i3)]...
        -[To(p(I)+i2-i3), To(p(I)+i2), To(p(I)+i2+i3)]).*x(I,[2,2,2]);
    dT(valid(I),1)= temp(:,2)+(temp(:,3)-temp(:,2)).*X2(I,3)...
            +1/(4*eta)*(temp(:,3)-2*temp(:,2)+temp(:,1)).*(X2(I,3)-eta).^2;
    % dtemp/dx2    
    temp = ([To(p(I)+i2-i3), To(p(I)+i2), To(p(I)+i2+i3)]...
        -[To(p(I)-i3), To(p(I)), To(p(I)+i3)]).*(1-x(I,[1,1,1]))...
        +([To(p(I)+i1+i2-i3),To(p(I)+i1+i2),To(p(I)+i1+i2+i3)]...
        -[To(p(I)+i1-i3), To(p(I)+i1), To(p(I)+i1+i3)]).*x(I,[1,1,1]);
    dT(valid(I),2)= temp(:,2)+(temp(:,3)-temp(:,2)).*X2(I,3)...
            +1/(4*eta)*(temp(:,3)-2*temp(:,2)+temp(:,1)).*(X2(I,3)-eta).^2;
end

% case B: x1 in eta  -  x2, x3 not in eta
I = find(x(:,2)>eta & x(:,2)<(1-eta) & x(:,3)>eta & x(:,3)<(1-eta) ...
      & (x(:,1)<=eta | x(:,1)>=(1-eta)) );
p  = (pad + P2(:,1)) + i2*(pad + P(:,2) - 1) + i3*(pad + P(:,3) -1);
% linear interpolation on three parallel planes (x2,x3)
temp = ([To(p(I)-i1),To(p(I)),To(p(I)+i1)].*(1-x(I,[2,2,2]))...
    +[To(p(I)+i2-i1),To(p(I)+i2),To(p(I)+i2+i1)]...
    .*x(I,[2,2,2])).*(1-x(I,[3,3,3]))...
    +([To(p(I)+i3-i1),To(p(I)+i3),To(p(I)+i3+i1)].*(1-x(I,[2,2,2]))...
    +[To(p(I)+i2+i3-i1),To(p(I)+i2+i3),To(p(I)+i2+i3+i1)]...
    .*x(I,[2,2,2])).*x(I,[3,3,3]);
% quadratic interpolation in x1-direction                      
Tc(valid(I))=temp(:,2)+(temp(:,3)-temp(:,2)).*X2(I,1)...
            +1/(4*eta)*(temp(:,3)-2*temp(:,2)+temp(:,1)).*(X2(I,1)-eta).^2; 
% compute derivative, if necessary
if doDerivative
    dT(valid(I),1)= (temp(:,3)-temp(:,2)) ... 
        +1/(2*eta)*(temp(:,3)-2*temp(:,2)+temp(:,1)).*(X2(I,1)-eta);
    % dtemp/dx2
    temp = ([To(p(I)+i2-i1),To(p(I)+i2),To(p(I)+i2+i1)]...
        -[To(p(I)-i1),To(p(I)),To(p(I)+i1)]).*(1-x(I,[3,3,3]))...
        +([To(p(I)+i2+i3-i1),To(p(I)+i2+i3),To(p(I)+i2+i3+i1)]...
        -[To(p(I)+i3-i1),To(p(I)+i3),To(p(I)+i3+i1)]).*x(I,[3,3,3]);
    dT(valid(I),2)= temp(:,2)+(temp(:,3)-temp(:,2)).*X2(I,1)...
            +1/(4*eta)*(temp(:,3)-2*temp(:,2)+temp(:,1)).*(X2(I,1)-eta).^2; 
    % dtemp/dx3    
    temp = ([To(p(I)+i3-i1),To(p(I)+i3),To(p(I)+i3+i1)]...
        -[To(p(I)-i1),To(p(I)),To(p(I)+i1)]).*(1-x(I,[2,2,2]))...
        +([To(p(I)+i2+i3-i1),To(p(I)+i2+i3),To(p(I)+i2+i3+i1)]...
        -[To(p(I)+i2-i1),To(p(I)+i2),To(p(I)+i2+i1)]).*x(I,[2,2,2]);
    dT(valid(I),3)= temp(:,2)+(temp(:,3)-temp(:,2)).*X2(I,1)...
            +1/(4*eta)*(temp(:,3)-2*temp(:,2)+temp(:,1)).*(X2(I,1)-eta).^2;
end

% case C: x2 in eta  - x1, x3 not in eta
I = find(x(:,1)>eta & x(:,1)<(1-eta) & x(:,3)>eta & x(:,3)<(1-eta) ...
      & (x(:,2)<=eta | x(:,2)>=(1-eta)) );
p  = (pad + P(:,1)) + i2*(pad + P2(:,2) - 1) + i3*(pad + P(:,3) -1);
% linear interpolation on three parallel planes (x1,x3)
temp = ([To(p(I)-i2), To(p(I)), To(p(I)+i2)].*(1-x(I,[1,1,1]))...
    +[To(p(I)+i1-i2),To(p(I)+i1),To(p(I)+i1+i2)]...
    .*x(I,[1,1,1])).*(1-x(I,[3,3,3]))...
    +([To(p(I)+i3-i2),To(p(I)+i3),To(p(I)+i3+i2)].*(1-x(I,[1,1,1]))...
    +[To(p(I)+i1+i3-i2),To(p(I)+i1+i3),To(p(I)+i1+i3+i2)]...
    .*x(I,[1,1,1])).*x(I,[3,3,3]);
% quadratic interpolation in x2-direction                      
Tc(valid(I))=temp(:,2)+(temp(:,3)-temp(:,2)).*X2(I,2)...
            +1/(4*eta)*(temp(:,3)-2*temp(:,2)+temp(:,1)).*(X2(I,2)-eta).^2; 

if doDerivative
    dT(valid(I),2)= temp(:,3)-temp(:,2) ... 
        +1/(2*eta)*(temp(:,3)-2*temp(:,2)+temp(:,1)).*(X2(I,2)-eta);
    % dtemp/dx1
    temp = ([To(p(I)+i1-i2),To(p(I)+i1),To(p(I)+i1+i2)]...
        -[To(p(I)-i2), To(p(I)), To(p(I)+i2)]).*(1-x(I,[3,3,3]))...
        +([To(p(I)+i1+i3-i2),To(p(I)+i1+i3),To(p(I)+i1+i3+i2)]...
        -[To(p(I)+i3-i2),To(p(I)+i3),To(p(I)+i3+i2)]).*x(I,[3,3,3]);
    dT(valid(I),1)= temp(:,2)+(temp(:,3)-temp(:,2)).*X2(I,2)...
            +1/(4*eta)*(temp(:,3)-2*temp(:,2)+temp(:,1)).*(X2(I,2)-eta).^2;
    % dtemp/dx3    
    temp = ([To(p(I)+i3-i2),To(p(I)+i3),To(p(I)+i3+i2)]...
        -[To(p(I)-i2), To(p(I)), To(p(I)+i2)]).*(1-x(I,[1,1,1]))...
        +([To(p(I)+i1+i3-i2),To(p(I)+i1+i3),To(p(I)+i1+i3+i2)]...
        -[To(p(I)+i1-i2),To(p(I)+i1),To(p(I)+i1+i2)]).*x(I,[1,1,1]);
    dT(valid(I),3)= temp(:,2)+(temp(:,3)-temp(:,2)).*X2(I,2)...
            +1/(4*eta)*(temp(:,3)-2*temp(:,2)+temp(:,1)).*(X2(I,2)-eta).^2;
end

% third case: exactly two compentents in eta
% again we have to consider 3 cases
% case A: x1,x3 in eta - x2 not in eta
% case B: x1,x2 in eta - x3 not in eta
% case C: x2,x3 in eta - x1 not in eta 
% idea: compute 3 points on parallel planes, the planes are given
%       by the condition - one component is in eta, the other is not in eta
%       This points can be handled as in 2D. 
%       At last a quadratic interpolation can be performed 

% case A: x1, x3 in eta, x2 not in eta
I = find((x(:,1)<=eta |x(:,1) >=(1-eta))& x(:,2)>eta & x(:,2)<(1-eta)...
       & (x(:,3)<=eta |x(:,3) >=(1-eta)));
p  = (pad + P2(:,1)) + i2*(pad + P(:,2) - 1) + i3*(pad + P2(:,3) -1);

% compute 3 points on 3 parallel planes (x1,x2) 
% for each of the 3 points on the planes, 3 more points are needed
% (computed by linear interpolation in x2-direction)
t = x(I,[2,2,2,2,2,2,2,2,2])...
    .*([To(p(I)+i2-i1-i3),To(p(I)+i2-i3),To(p(I)+i2+i1-i3),...
        To(p(I)+i2-i1),To(p(I)+i2),To(p(I)+i2+i1),...
        To(p(I)+i2-i1+i3),To(p(I)+i2+i3),To(p(I)+i2+i1+i3)]...
    -[To(p(I)-i1-i3),To(p(I)-i3),To(p(I)+i1-i3),...
      To(p(I)-i1),To(p(I)),To(p(I)+i1),...
      To(p(I)-i1+i3),To(p(I)+i3),To(p(I)+i1+i3)])...
    +[To(p(I)-i1-i3),To(p(I)-i3),To(p(I)+i1-i3),...
      To(p(I)-i1),To(p(I)),To(p(I)+i1),...
      To(p(I)-i1+i3),To(p(I)+i3),To(p(I)+i1+i3)];
% compute points on planes via quadratic interpolation in x1-direction
temp = t(:,[2,5,8])+(t(:,[3,6,9])-t(:,[2,5,8])).*X2(I,[1,1,1])...
        +1/(4*eta)*(t(:,[3,6,9])-2*t(:,[2,5,8])+t(:,[1,4,7]))...
        .*(X2(I,[1,1,1])-eta).^2;
% quadratic interpolation in x3-direction
Tc(valid(I))=temp(:,2)+(temp(:,3)-temp(:,2)).*X2(I,3)...
            +1/(4*eta)*(temp(:,3)-2*temp(:,2)+temp(:,1)).*(X2(I,3)-eta).^2;

if doDerivative
    dT(valid(I),3)= temp(:,3)-temp(:,2)...
            +1/(2*eta)*(temp(:,3)-2*temp(:,2)+temp(:,1)).*(X2(I,3)-eta);
    % dtemp/dx1    
    temp = t(:,[3,6,9])-t(:,[2,5,8])...
        +1/(2*eta)*(t(:,[3,6,9])-2*t(:,[2,5,8])+t(:,[1,4,7]))...
        .*(X2(I,[1,1,1])-eta);
    dT(valid(I),1)= temp(:,2)+(temp(:,3)-temp(:,2)).*X2(I,3)...
            +1/(4*eta)*(temp(:,3)-2*temp(:,2)+temp(:,1)).*(X2(I,3)-eta).^2;
    % dt/dx2    
    t =[To(p(I)+i2-i1-i3),To(p(I)+i2-i3),To(p(I)+i2+i1-i3),...
        To(p(I)+i2-i1),To(p(I)+i2),To(p(I)+i2+i1),...
        To(p(I)+i2-i1+i3),To(p(I)+i2+i3),To(p(I)+i2+i1+i3)]...
    -[To(p(I)-i1-i3),To(p(I)-i3),To(p(I)+i1-i3),...
      To(p(I)-i1),To(p(I)),To(p(I)+i1),...
      To(p(I)-i1+i3),To(p(I)+i3),To(p(I)+i1+i3)];
    % dtemp/dx2
    temp = t(:,[2,5,8])+(t(:,[3,6,9])-t(:,[2,5,8])).*X2(I,[1,1,1])...
        +1/(4*eta)*(t(:,[3,6,9])-2*t(:,[2,5,8])+t(:,[1,4,7]))...
        .*(X2(I,[1,1,1])-eta).^2;
    dT(valid(I),2)= temp(:,2)+(temp(:,3)-temp(:,2)).*X2(I,3)...
            +1/(4*eta)*(temp(:,3)-2*temp(:,2)+temp(:,1)).*(X2(I,3)-eta).^2;
end

% case B: x1, x2 in eta, x3 not in eta
I = find((x(:,1)<=eta |x(:,1) >=(1-eta))&(x(:,2)<=eta |x(:,2) >=(1-eta))...
        & x(:,3)>eta & x(:,3)<(1-eta) );
p  = (pad + P2(:,1)) + i2*(pad + P2(:,2) - 1) + i3*(pad + P(:,3) -1);

% compute 3 points on 3 parallel planes (x1,x3) 
% for each of the 3 points on the planes, 3 more points are needed
% (computed by linear interpolation in x3-direction)
t = x(I,[3,3,3,3,3,3,3,3,3])...
    .*([To(p(I)+i3-i1-i2),To(p(I)+i3-i2),To(p(I)+i3+i1-i2),...
       To(p(I)+i3-i1),To(p(I)+i3),To(p(I)+i3+i1),...
       To(p(I)+i3-i1+i2),To(p(I)+i3+i2),To(p(I)+i3+i1+i2)]...
    -[To(p(I)-i1-i2),To(p(I)-i2),To(p(I)+i1-i2),...
      To(p(I)-i1),To(p(I)),To(p(I)+i1),...
      To(p(I)-i1+i2),To(p(I)+i2),To(p(I)+i1+i2)])...
    +[To(p(I)-i1-i2),To(p(I)-i2),To(p(I)+i1-i2),...
      To(p(I)-i1),To(p(I)),To(p(I)+i1),...
      To(p(I)-i1+i2),To(p(I)+i2),To(p(I)+i1+i2)];
% compute points on planes via quadratic interpolation in x1-direction             
temp = t(:,[2,5,8])+(t(:,[3,6,9])-t(:,[2,5,8])).*X2(I,[1,1,1])...
        +1/(4*eta)*(t(:,[3,6,9])-2*t(:,[2,5,8])+t(:,[1,4,7]))...
        .*(X2(I,[1,1,1])-eta).^2;
% quadratic interpolation in x2-direction
Tc(valid(I))=temp(:,2)+(temp(:,3)-temp(:,2)).*X2(I,2)...
            +1/(4*eta)*(temp(:,3)-2*temp(:,2)+temp(:,1)).*(X2(I,2)-eta).^2;
% compute derivative, if necessary
if doDerivative
    dT(valid(I),2)= temp(:,3)-temp(:,2)...
            +1/(2*eta)*(temp(:,3)-2*temp(:,2)+temp(:,1)).*(X2(I,2)-eta);
    % dtemp/dx1
    temp = t(:,[3,6,9])-t(:,[2,5,8])...
        +1/(2*eta)*(t(:,[3,6,9])-2*t(:,[2,5,8])+t(:,[1,4,7]))...
        .*(X2(I,[1,1,1])-eta);
    dT(valid(I),1)= temp(:,2)+(temp(:,3)-temp(:,2)).*X2(I,2)...
            +1/(4*eta)*(temp(:,3)-2*temp(:,2)+temp(:,1)).*(X2(I,2)-eta).^2;
    %dt/dx3
    t =[To(p(I)+i3-i1-i2),To(p(I)+i3-i2),To(p(I)+i3+i1-i2),...
       To(p(I)+i3-i1),To(p(I)+i3),To(p(I)+i3+i1),...
       To(p(I)+i3-i1+i2),To(p(I)+i3+i2),To(p(I)+i3+i1+i2)]...
    -[To(p(I)-i1-i2),To(p(I)-i2),To(p(I)+i1-i2),...
      To(p(I)-i1),To(p(I)),To(p(I)+i1),...
      To(p(I)-i1+i2),To(p(I)+i2),To(p(I)+i1+i2)];
    % dtemp/dx3
    temp = t(:,[2,5,8])+(t(:,[3,6,9])-t(:,[2,5,8])).*X2(I,[1,1,1])...
        +1/(4*eta)*(t(:,[3,6,9])-2*t(:,[2,5,8])+t(:,[1,4,7]))...
        .*(X2(I,[1,1,1])-eta).^2;
    dT(valid(I),3)= temp(:,2)+(temp(:,3)-temp(:,2)).*X2(I,2)...
            +1/(4*eta)*(temp(:,3)-2*temp(:,2)+temp(:,1)).*(X2(I,2)-eta).^2;
end

% case C: x2, x3 in eta, x1 not in eta
I = find(x(:,1)>eta & x(:,1)<(1-eta) & (x(:,2)<=eta |x(:,2) >=(1-eta))...
      & (x(:,3)<=eta |x(:,3) >=(1-eta)));
p  = (pad + P(:,1)) + i2*(pad + P2(:,2) - 1) + i3*(pad + P2(:,3) -1);

% compute 3 points on 3 parallel planes (x1,x3) 
% for each of the 3 points on the planes, 3 more points are needed
% (computed by linear interpolation in x1-direction)
t = x(I,[1 1 1 1 1 1 1 1 1])...
    .*([To(p(I)+i1-i3-i2),To(p(I)+i1-i2),To(p(I)+i1+i3-i2),...
        To(p(I)+i1-i3),To(p(I)+i1),To(p(I)+i1+i3),...
        To(p(I)+i1-i3+i2),To(p(I)+i1+i2),To(p(I)+i1+i3+i2)]...
    -[To(p(I)-i3-i2),To(p(I)-i2),To(p(I)+i3-i2),...
      To(p(I)-i3),To(p(I)),To(p(I)+i3),...
      To(p(I)-i3+i2),To(p(I)+i2),To(p(I)+i3+i2)])...
    +[To(p(I)-i3-i2),To(p(I)-i2),To(p(I)+i3-i2),...
      To(p(I)-i3),To(p(I)),To(p(I)+i3),...
      To(p(I)-i3+i2),To(p(I)+i2),To(p(I)+i3+i2)];

% compute points on planes via quadratic interpolation in x1-direction     
temp = t(:,[2,5,8])+(t(:,[3,6,9])-t(:,[2,5,8])).*X2(I,[3,3,3])...
        +1/(4*eta)*(t(:,[3,6,9])-2*t(:,[2,5,8])+t(:,[1,4,7]))...
        .*(X2(I,[3,3,3])-eta).^2;
% quadratic interpolation in x2-direction
Tc(valid(I))=temp(:,2)+(temp(:,3)-temp(:,2)).*X2(I,2)...
            +1/(4*eta)*(temp(:,3)-2*temp(:,2)+temp(:,1)).*(X2(I,2)-eta).^2;        
% compute derivative, if necessary
if doDerivative
    dT(valid(I),2)= temp(:,3)-temp(:,2)...
            +1/(2*eta)*(temp(:,3)-2*temp(:,2)+temp(:,1)).*(X2(I,2)-eta);
    % dtemp/dx3    
    temp=t(:,[3,6,9])-t(:,[2,5,8])...
        +1/(2*eta)*(t(:,[3,6,9])-2*t(:,[2,5,8])+t(:,[1,4,7]))...
        .*(X2(I,[3,3,3])-eta);    
    dT(valid(I),3)= temp(:,2)+(temp(:,3)-temp(:,2)).*X2(I,2)...
            +1/(4*eta)*(temp(:,3)-2*temp(:,2)+temp(:,1)).*(X2(I,2)-eta).^2;        
    % dt/dx1
    t = [To(p(I)+i1-i3-i2),To(p(I)+i1-i2),To(p(I)+i1+i3-i2),...
        To(p(I)+i1-i3),To(p(I)+i1),To(p(I)+i1+i3),...
        To(p(I)+i1-i3+i2),To(p(I)+i1+i2),To(p(I)+i1+i3+i2)]...
    -[To(p(I)-i3-i2),To(p(I)-i2),To(p(I)+i3-i2),...
      To(p(I)-i3),To(p(I)),To(p(I)+i3),...
      To(p(I)-i3+i2),To(p(I)+i2),To(p(I)+i3+i2)];
    % dtemp/dx1
    temp = t(:,[2,5,8])+(t(:,[3,6,9])-t(:,[2,5,8])).*X2(I,[3,3,3])...
        +1/(4*eta)*(t(:,[3,6,9])-2*t(:,[2,5,8])+t(:,[1,4,7]))...
        .*(X2(I,[3,3,3])-eta).^2;
    dT(valid(I),1)= temp(:,2)+(temp(:,3)-temp(:,2)).*X2(I,2)...
            +1/(4*eta)*(temp(:,3)-2*temp(:,2)+temp(:,1)).*(X2(I,2)-eta).^2;        
end

% third case: all components in eta
% idea: compute 3 points on parallel planes the same way as in 2D
%       (case: both components in eta). Then again quadratic interpolation 
%       in the remaining direction 

% all components in eta
I = find((x(:,1)<=eta |x(:,1)>=(1-eta))&(x(:,2)<=eta |x(:,2) >=(1-eta))...
       & (x(:,3)<=eta |x(:,3) >=(1-eta)));
p  = (pad + P2(:,1)) + i2*(pad + P2(:,2) - 1) + i3*(pad + P2(:,3) -1);

% quadratic interpolation in x2-direction
t = [To(p(I)-i1-i3),To(p(I)-i3),To(p(I)+i1-i3),...
     To(p(I)-i1),To(p(I)),To(p(I)+i1),...
     To(p(I)-i1+i3),To(p(I)+i3),To(p(I)+i1+i3)]...
    +([To(p(I)-i1+i2-i3),To(p(I)+i2-i3),To(p(I)+i1+i2-i3),...
       To(p(I)-i1+i2),To(p(I)+i2),To(p(I)+i1+i2),...
       To(p(I)-i1+i2+i3),To(p(I)+i2+i3),To(p(I)+i1+i2+i3)]...
     -[To(p(I)-i1-i3),To(p(I)-i3),To(p(I)+i1-i3),...
       To(p(I)-i1),To(p(I)),To(p(I)+i1),...
       To(p(I)-i1+i3),To(p(I)+i3),To(p(I)+i1+i3)])...
    .*X2(I,[2,2,2,2,2,2,2,2,2])...
    +1/(4*eta)*([To(p(I)-i1+i2-i3),To(p(I)+i2-i3),To(p(I)+i1+i2-i3),...
                  To(p(I)-i1+i2),To(p(I)+i2),To(p(I)+i1+i2),...
                  To(p(I)-i1+i2+i3),To(p(I)+i2+i3),To(p(I)+i1+i2+i3)]...
                -2*[To(p(I)-i1-i3),To(p(I)-i3),To(p(I)+i1-i3),...   
                    To(p(I)-i1),To(p(I)),To(p(I)+i1),...
                    To(p(I)-i1+i3),To(p(I)+i3),To(p(I)+i1+i3)]...
                +[To(p(I)-i1-i2-i3),To(p(I)-i2-i3),To(p(I)+i1-i2-i3),...
                  To(p(I)-i1-i2),To(p(I)-i2),To(p(I)+i1-i2),...
                  To(p(I)-i1-i2+i3),To(p(I)-i2+i3),To(p(I)+i1-i2+i3)])...
     .*(X2(I,[2,2,2,2,2,2,2,2,2])-eta).^2;
% quadratic interpolation in x1-direction
temp = t(:,[2,5,8])+(t(:,[3,6,9])-t(:,[2,5,8])).*X2(I,[1,1,1])...
              +1/(4*eta)*(t(:,[3,6,9])-2*t(:,[2,5,8])+t(:,[1,4,7]))...
                .*(X2(I,[1,1,1])-eta).^2;
% quadratic interpolation in x3-direction            
Tc(valid(I))=temp(:,2)+(temp(:,3)-temp(:,2)).*X2(I,3)...
    +1/(4*eta)*(temp(:,3)-2*temp(:,2)+temp(:,1)).*(X2(I,3)-eta).^2;
% compute derivative, if necessary
if doDerivative 
    dT(valid(I),3) = temp(:,3)-temp(:,2)...
        +1/(2*eta)*(temp(:,3)-2*temp(:,2)+temp(:,1)).*(X2(I,3)-eta);
    % dtemp/dx1
    temp = t(:,[3,6,9])-t(:,[2,5,8])...
              +1/(2*eta)*(t(:,[3,6,9])-2*t(:,[2,5,8])+t(:,[1,4,7]))...
                .*(X2(I,[1,1,1])-eta);
    dT(valid(I),1) = temp(:,2)+(temp(:,3)-temp(:,2)).*X2(I,3)...
        +1/(4*eta)*(temp(:,3)-2*temp(:,2)+temp(:,1)).*(X2(I,3)-eta).^2;
    % dt/dx2
    t =[To(p(I)-i1+i2-i3),To(p(I)+i2-i3),To(p(I)+i1+i2-i3),...
       To(p(I)-i1+i2),To(p(I)+i2),To(p(I)+i1+i2),...
       To(p(I)-i1+i2+i3),To(p(I)+i2+i3),To(p(I)+i1+i2+i3)]...
     -[To(p(I)-i1-i3),To(p(I)-i3),To(p(I)+i1-i3),...
       To(p(I)-i1),To(p(I)),To(p(I)+i1),...
       To(p(I)-i1+i3),To(p(I)+i3),To(p(I)+i1+i3)]...
    +1/(2*eta)*([To(p(I)-i1+i2-i3),To(p(I)+i2-i3),To(p(I)+i1+i2-i3),...
                  To(p(I)-i1+i2),To(p(I)+i2),To(p(I)+i1+i2),...
                  To(p(I)-i1+i2+i3),To(p(I)+i2+i3),To(p(I)+i1+i2+i3)]...
                -2*[To(p(I)-i1-i3),To(p(I)-i3),To(p(I)+i1-i3),...   
                    To(p(I)-i1),To(p(I)),To(p(I)+i1),...
                    To(p(I)-i1+i3),To(p(I)+i3),To(p(I)+i1+i3)]...
                +[To(p(I)-i1-i2-i3),To(p(I)-i2-i3),To(p(I)+i1-i2-i3),...
                  To(p(I)-i1-i2),To(p(I)-i2),To(p(I)+i1-i2),...
                  To(p(I)-i1-i2+i3),To(p(I)-i2+i3),To(p(I)+i1-i2+i3)])...
     .*(X2(I,[2,2,2,2,2,2,2,2,2])-eta);
    % dtemp/dx2
    temp = t(:,[2,5,8])+(t(:,[3,6,9])-t(:,[2,5,8])).*X2(I,[1,1,1])...
              +1/(4*eta)*(t(:,[3,6,9])-2*t(:,[2,5,8])+t(:,[1,4,7]))...
                .*(X2(I,[1,1,1])-eta).^2;
    dT(valid(I),2) = temp(:,2)+(temp(:,3)-temp(:,2)).*X2(I,3)...
    +1/(4*eta)*(temp(:,3)-2*temp(:,2)+temp(:,1)).*(X2(I,3)-eta).^2;
end
 
% ===================================================================================
function runMinimalExample

  help(mfilename);
  fprintf('%s: minimal examples\n',mfilename)

  % 1D example
  omega = [0,10];
  Tdata = [0,1,4,1,0]; 
  Tcoef = Tdata;
  m     = length(Tdata);
  Xdata = getCellCenteredGrid(omega,m);
  xc    = linspace(-1,11,101);
  [T0,dT0] = feval(mfilename,Tcoef,omega,xc);

  figure(1); clf;
  subplot(1,2,1); plot(xc,T0,'b-',Xdata,Tdata,'ro'); 
  title(sprintf('%s %d-dim',mfilename,1));
  subplot(1,2,2); spy(dT0);                     
  title('dT')

  % 2D example
  omega = [0,10,0,8];
  Tdata = [1,2,3,4;1,2,3,4;4,4,4,4]; m = size(Tdata);
  Tcoef = Tdata;
  Xdata    = getCellCenteredGrid(omega,m);
  xc    = getCellCenteredGrid(omega+[-1 1 -1 1],5*m);
  [Tc,dT] = feval(mfilename,Tcoef,omega,xc);
  DD = reshape([Xdata;Tdata(:)],[],3);
  Dc = reshape([xc;Tc],[5*m,3]);

  figure(2); clf;
  subplot(1,2,1);  surf(Dc(:,:,1),Dc(:,:,2),Dc(:,:,3));  hold on;
  plot3(DD(:,1),DD(:,2),DD(:,3),'r.','markersize',40); hold off;
  title(sprintf('%s %d-dim',mfilename,2));
  subplot(1,2,2); spy(dT);                     
  title('dT')

  % 3D example
  omega = [0,1,0,2,0,1]; m = [13,16,7];
  Xdata    = getCellCenteredGrid(omega,m);
  Y     = reshape(Xdata,[m,3]);
  Tdata = (Y(:,:,:,1)-0.5).^2 + (Y(:,:,:,2)-0.75).^2 + (Y(:,:,:,3)-0.5).^2 <= 0.15;
  Tcoef = reshape(Tdata,m);
  xc    = getCellCenteredGrid(omega,4*m);
  [Tc,dT] = feval(mfilename,Tcoef,omega,xc);

  figure(3); clf;
  subplot(1,2,1); imgmontage(Tc,omega,4*m);
  title(sprintf('%s %d-dim',mfilename,3));
  subplot(1,2,2); spy(dT);                 
  title('dT')

  fctn = @(xc) feval(mfilename,Tcoef,omega,xc);
  xc   = xc + rand(size(xc));
  checkDerivative(fctn,xc)

  %{ 
	=======================================================================================
	FAIR: Flexible Algorithms for Image Registration, Version 2011
	Copyright (c): Jan Modersitzki
	Maria-Goeppert-Str. 1a, D-23562 Luebeck, Germany
	Email: jan.modersitzki@mic.uni-luebeck.de
	URL:   http://www.mic.uni-luebeck.de/people/jan-modersitzki.html
	=======================================================================================
	No part of this code may be reproduced, stored in a retrieval system,
	translated, transcribed, transmitted, or distributed in any form
	or by any means, means, manual, electric, electronic, electro-magnetic,
	mechanical, chemical, optical, photocopying, recording, or otherwise,
	without the prior explicit written permission of the authors or their
	designated proxies. In no event shall the above copyright notice be
	removed or altered in any way.

	This code is provided "as is", without any warranty of any kind, either
	expressed or implied, including but not limited to, any implied warranty
	of merchantibility or fitness for any purpose. In no event will any party
	who distributed the code be liable for damages or for any claim(s) by
	any other party, including but not limited to, any lost profits, lost
	monies, lost data or data rendered inaccurate, losses sustained by
	third parties, or any other special, incidental or consequential damages
	arrising out of the use or inability to use the program, even if the
	possibility of such damages has been advised against. The entire risk
	as to the quality, the performace, and the fitness of the program for any
	particular purpose lies with the party using the code.
	=======================================================================================
	Any use of this code constitutes acceptance of the terms of the above statements
	=======================================================================================
%}