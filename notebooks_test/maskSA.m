function tf = maskSA(X,Y,xv,yv)
    [inep,onep] = inpolygon(X,Y,xv(:,1),xv(:,2));
    [inen,onen] = inpolygon(X,Y,yv(:,1),yv(:,2));
    tf = (inep & ~inen) | onep | onen;
end