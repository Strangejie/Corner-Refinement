function ProjFiltered = FilterProjectedCornersOnEdge(ProjIn, GridCoords, LensRadius, edgePix)


    if nargin < 4 || isempty(edgePix), edgePix = 0; end
    ProjFiltered = ProjIn;
    if isempty(ProjIn), return; end

    H = size(GridCoords,1); W = size(GridCoords,2);
    maxID = H*W;
    id   = ProjIn(:,3);
    validID = id>=1 & id<=maxID & all(isfinite(ProjIn(:,1:2)),2);
    if ~any(validID)
        ProjFiltered = zeros(0,3);
        return;
    end
    ProjIn = ProjIn(validID,:); id = ProjIn(:,3);

    cx = GridCoords(:,:,1); cy = GridCoords(:,:,2);
    cx = cx(id); cy = cy(id);

    dx = ProjIn(:,1) - cx;
    dy = ProjIn(:,2) - cy;
    d  = hypot(dx, dy);

    effR = max(LensRadius - max(edgePix,0), 0); 
    keep = (d <= effR);

    ProjFiltered = ProjIn(keep, :);
end
