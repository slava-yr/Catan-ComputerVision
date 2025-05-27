clear; close all; clc;

figure('Name','Imagen sin fondo');
figure('Name','Máscara del mar refinada');
figure('Name','Máscara final del tablero');
figure('Name','Recorte sin mar');

for i = 1:10
    % Leer imagen original
    I = imread(sprintf('imgs2/catan %d.jpeg', i));
    hsv = rgb2hsv(I);

    % --- PRIMERA ETAPA: eliminar el fondo marino (contorno convexo)
    mar_mask = (hsv(:,:,1) > 0.5 & hsv(:,:,1) < 0.7) & ...
               (hsv(:,:,2) > 0.4) & (hsv(:,:,3) > 0.3);
    mar_mask = imclose(imopen(mar_mask, strel('disk',5)), strel('disk',10));
    mar_mask = imfill(mar_mask,'holes');

    % Extraer región marina más grande
    CC = bwconncomp(mar_mask);
    numPixels = cellfun(@numel, CC.PixelIdxList);
    mask_largest = false(size(mar_mask));
    if ~isempty(numPixels)
        mask_largest(CC.PixelIdxList{numPixels == max(numPixels)}) = true;
    end

    % Contorno convexo
    [y,x] = find(bwperim(mask_largest));
    if numel(x) >= 3
        K = convhull(x, y);
        mask_poly = poly2mask(x(K), y(K), size(mar_mask,1), size(mar_mask,2));
    else
        mask_poly = false(size(mar_mask));
    end

    % Aplicar máscara poligonal
    img_sin_fondo = I;
    for c = 1:3
        canal = img_sin_fondo(:,:,c);
        canal(~mask_poly) = 0;
        img_sin_fondo(:,:,c) = canal;
    end

    % Mostrar imagen sin fondo
    figure(1); subplot(2,5,i);
    imshow(img_sin_fondo); title(sprintf('Sin fondo %d', i));

    % --- SEGUNDA ETAPA: quitar el mar restante y recortar ---
    I2 = img_sin_fondo;
    hsv2 = rgb2hsv(I2);
    H = hsv2(:,:,1);
    S = hsv2(:,:,2);
    V = hsv2(:,:,3);

    % Máscara más fina del mar (ajuste fino)
    blueMask = (H > 0.5 & H < 0.67) & (S > 0.1) & (V > 0.15);
    figure(2); subplot(2,5,i);
    imshow(blueMask); title(sprintf('Mar refinado %d', i));

    % Invertir y limpiar para obtener solo tablero
    boardMask = ~blueMask;
    boardMask = bwareaopen(boardMask, 9000); % eliminar manchas pequeñas
    boardMask = imclose(boardMask, strel('disk',1));
    figure(3); subplot(2,5,i);
    imshow(boardMask); title(sprintf('Máscara tablero %d', i));

    % Aplicar la nueva máscara
    maskedImg = I2;
    for c = 1:3
        channel = maskedImg(:,:,c);
        channel(~boardMask) = 0;
        maskedImg(:,:,c) = channel;
    end

    % Recortar al bounding box
    stats = regionprops(boardMask, 'BoundingBox');
    if isempty(stats)
        warning('No se encontró tablero en la imagen %d', i);
        continue;
    end
    bb = stats(1).BoundingBox;
    croppedImg = imcrop(maskedImg, bb);

    % Mostrar resultado final
    figure(4); subplot(2,5,i);
    imshow(croppedImg); title(sprintf('Recorte final %d', i));

    % Guardar si deseas
    % imwrite(croppedImg, sprintf('salidas/recorte_final_%d.png', i));
end
