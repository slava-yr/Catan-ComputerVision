clc; clear; close all;

% --- PARTE 1: Cargar y rectificar imagen ---
img = imread('imgs/catan_black.jpg');
gray = rgb2gray(img);
bw = imbinarize(gray, 'adaptive');
bw = imcomplement(bw);
bw = imopen(bw, strel('disk', 5));

stats = regionprops(bw, 'BoundingBox', 'ConvexHull', 'Area');
[~, idx] = max([stats.Area]);
hull = stats(idx).ConvexHull;

[~, idx1] = min(hull(:,1) + hull(:,2));
[~, idx2] = min(-hull(:,1) + hull(:,2));
[~, idx3] = max(hull(:,1) + hull(:,2));
[~, idx4] = max(-hull(:,1) + hull(:,2));

movingPoints = [hull(idx1,:); hull(idx2,:); hull(idx3,:); hull(idx4,:)];
width = 800; height = 700;
fixedPoints = [0 0; width 0; width height; 0 height];
tform = fitgeotrans(movingPoints, fixedPoints, 'projective');
img_rect = imwarp(img, tform, 'OutputView', imref2d([height width]));

imwrite(img_rect, 'catan_rectificado.png');
disp('✅ Imagen corregida guardada como "catan_rectificado.png".');

% --- PARTE 2: Detección de losetas ---
img = imread('catan_rectificado.png');
[h, w, ~] = size(img);

hex_radius = 85;  % ajustable
start_x = 140;    
start_y = 140;    
hex_height = sqrt(3) * hex_radius;
num_tiles = [3 4 5 4 3];
tile_centers = [];
idx = 0;

for row = 1:length(num_tiles)
    num = num_tiles(row);
    offset_x = start_x + ((5 - num) * 1.5 * hex_radius / 2);
    y = start_y + (row - 1) * (hex_height * 0.75);
    for col = 1:num
        x = offset_x + (col - 1) * 1.5 * hex_radius;
        idx = idx + 1;
        tile_centers(idx,:) = [x, y];
    end
end

figure; imshow(img); hold on;
for i = 1:19
    plot(tile_centers(i,1), tile_centers(i,2), 'ro', 'MarkerSize', 10, 'LineWidth', 2);
    text(tile_centers(i,1), tile_centers(i,2), num2str(i), 'Color', 'yellow', 'FontSize', 12, ...
        'FontWeight', 'bold', 'HorizontalAlignment','center');
end
title('Verifica que los puntos estén centrados');

% --- PARTE 3: Clasificación automática por color ---
radius = 30;
img_hsv = rgb2hsv(img);
H = img_hsv(:,:,1); S = img_hsv(:,:,2); V = img_hsv(:,:,3);
tipos = strings(19,1);

for i = 1:19
    x = round(tile_centers(i,1));
    y = round(tile_centers(i,2));
    
    [X, Y] = meshgrid(1:size(img,2), 1:size(img,1));
    mask = (X - x).^2 + (Y - y).^2 <= radius^2;
    
    hue = mean(H(mask));
    sat = mean(S(mask));
    val = mean(V(mask));

    fprintf('\n🧪 LOSETA %d: hue=%.2f | sat=%.2f | val=%.2f\n', i, hue, sat, val);

    
    % Clasificación por HSV
    if val > 0.78 && sat < 0.25
    tipo = "Desierto";                         % brillante y poco saturado
    elseif hue > 0.26 && hue < 0.29 && sat >= 0.24 && sat <= 0.28 
        tipo = "Bosque";                           % verde intermedio
    elseif hue >= 0.25 && hue <= 0.27 && sat >= 0.31 && sat <= 0.37
        tipo = "Pastos";                           % verde claro saturado
    elseif hue >= 0.10 && hue <= 0.18 && sat > 0.3 && val > 0.68
        tipo = "Cultivos";                         % amarillo-ocre claro
    elseif hue > 0.32 && hue < 0.48 && sat >= 0.12 && sat <= 0.22
        tipo = "Montaña";                          % marrón/rojo saturado
    elseif hue < 0.10 && sat < 0.41
        tipo = "Cantera";                          % marrón/grisáceo tenue
    else
        tipo = "Indefinido";
    end


    tipos(i) = tipo;
    
    % Mostrar tipo en imagen
    text(x, y+25, tipo, 'Color', 'cyan', 'FontSize', 10, ...
        'FontWeight', 'bold', 'HorizontalAlignment','center');
end

% --- PARTE 4: Recorte y guardado de losetas ---
for i = 1:19
    x = tile_centers(i,1);
    y = tile_centers(i,2);
    r = round(hex_radius * 1.05);
    x1 = max(1, round(x - r));
    y1 = max(1, round(y - r));
    x2 = min(w, round(x + r));
    y2 = min(h, round(y + r));
    
    patch = img(y1:y2, x1:x2, :);
    filename = sprintf('loseta_%02d.png', i);
    imwrite(patch, filename);
end
disp('✅ Losetas recortadas.');

% --- PARTE 5: Exportar resultados ---
T = table((1:19)', round(tile_centers(:,1)), round(tile_centers(:,2)), tipos, ...
    'VariableNames', {'#','X','Y','Tipo'});
disp(T);
writetable(T, 'clasificacion_losetas.csv');
disp('✅ Clasificación guardada en "clasificacion_losetas.csv".');
