clear;close;clc;
figure('Name','Contornos Convexos','NumberTitle','off');
figure('Name','Máscaras de Recorte','NumberTitle','off');
% Entrada: Imagen original
% Salida: Máscara del tablero [mask_poly]

for i = 1:10
    I = imread(sprintf('imgs2/catan %d.jpeg', i));
    hsv = rgb2hsv(I);
    % Máscara de mar
    mar_mask = (hsv(:,:,1)>0.5 & hsv(:,:,1)<0.7) & (hsv(:,:,2)>0.4) & (hsv(:,:,3)>0.3);
    mar_mask = imclose(imopen(mar_mask, strel('disk',5)), strel('disk',10));
    mar_mask = imfill(mar_mask,'holes');

    CC = bwconncomp(mar_mask);
    numPixels = cellfun(@numel, CC.PixelIdxList);
    mask_largest = false(size(mar_mask));
    if ~isempty(numPixels)
        mask_largest(CC.PixelIdxList{numPixels == max(numPixels)}) = true;
    end

    [y,x] = find(bwperim(mask_largest));
    if numel(x) >= 3
        K = convhull(x, y);
    else
        K = [];
    end

    if ~isempty(K)
        mask_poly = poly2mask(x(K), y(K), size(mar_mask,1), size(mar_mask,2));
    else
        mask_poly = false(size(mar_mask));
    end
    
    % Mostrar imagen con polígono
    figure(1);
    subplot(2,5,i);
    imshow(I); hold on;
    if ~isempty(K)
        plot(x(K), y(K), 'r', 'LineWidth', 2);
    end
    title(sprintf('Contorno %d', i));

    % Mostrar máscara binaria
    figure(2);
    subplot(2,5,i);
    imshow(mask_poly);
    title(sprintf('Máscara %d', i));
end
