clear; close all; clc;

figure('Name','Imagen sin fondo (contorno)');
figure('Name','Máscara por K-means');
figure('Name','Tablero final limpio');

i = 2
% Leer imagen original
I = imread(sprintf('imgs2/catan %d.jpeg', i));
hsv = rgb2hsv(I);

% --- PASO 1: Eliminar fondo por contorno convexo del mar ---
mar_mask = (hsv(:,:,1) > 0.5 & hsv(:,:,1) < 0.7) & ...
           (hsv(:,:,2) > 0.4) & (hsv(:,:,3) > 0.3);
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
    mask_poly = poly2mask(x(K), y(K), size(mar_mask,1), size(mar_mask,2));
else
    mask_poly = false(size(mar_mask));
end

img_sin_fondo = I;
for c = 1:3
    canal = img_sin_fondo(:,:,c);
    canal(~mask_poly) = 0;
    img_sin_fondo(:,:,c) = canal;
end

figure(1); subplot(2,5,i);
imshow(img_sin_fondo); title(sprintf('Sin fondo %d', i));

% --- PASO 2: Extraer el tablero con K-means Lab sobre img_sin_fondo ---

imagen = img_sin_fondo;
imagen_double = im2double(imagen);

% Suavizado
imagen_suave = imbilatfilt(imagen_double, 1, 5);

% K-means en espacio Lab
lab = rgb2lab(imagen_suave);
L = imsegkmeans(single(lab), 2, 'NumAttempts', 5);

% Elegir el cluster del centro como tablero
[m, n, ~] = size(imagen);
centro = L(round(m/3):round(2*m/3), round(n/3):round(2*n/3));
modo = mode(centro(:));
mascara_tablero = (L == modo);

% Morfología
mascara_tablero = imfill(mascara_tablero, 'holes');
mascara_tablero = bwareaopen(mascara_tablero, 8000);
se = strel('disk', 5);
mascara_tablero = imclose(mascara_tablero, se);
mascara_tablero = bwareafilt(mascara_tablero, 1);
mascara_tablero = imopen(mascara_tablero, se);
mascara_tablero = imerode(mascara_tablero, strel('disk', 30));

figure(2); subplot(2,5,i);
imshow(mascara_tablero); title(sprintf('Máscara tablero %d', i));

% Aplicar la máscara final
imagen_segmentada = imagen;
for c = 1:3
    canal = imagen_segmentada(:,:,c);
    canal(~mascara_tablero) = 0;
    imagen_segmentada(:,:,c) = canal;
end

figure(3); subplot(2,5,i);
imshow(imagen_segmentada); title(sprintf('Final limpio %d', i));

% Guardar si se desea
imwrite(imagen_segmentada, sprintf('salidas/final_tablero_%d.png', i));


% Leer imagen original
ruta = sprintf('salidas/final_tablero_%d.png', i);
img = imread(ruta);
[h, w, ~] = size(img);
figure; imshow(img); title('Imagen original');

%%%%

%% --- 2: Preprocesamiento: filtro bilateral en LAB y CLAHE en L ---
lab = rgb2lab(img);

L = lab(:,:,1);
A = lab(:,:,2);
B = lab(:,:,3);

% Filtro bilateral para suavizar sin perder bordes
L_filt = imbilatfilt(L, 30, 10);
A_filt = imbilatfilt(A, 30, 10);
B_filt = imbilatfilt(B, 30, 10);

% Aplicar CLAHE agresivo en L suavizado
L_clahe = adapthisteq(L_filt / 100, 'ClipLimit', 0.05, 'Distribution', 'uniform');

% Mezclar CLAHE con L suavizado original para controlar efecto
alpha = 0.2; % peso a CLAHE
L_final = alpha * L_clahe * 100 + (1 - alpha) * L_filt;

% Reconstruir imagen LAB y convertir a RGB
lab_filt = cat(3, L_final, A_filt, B_filt);
img_bilateral = lab2rgb(lab_filt);
img_bilateral=imgaussfilt(img_bilateral,2);
img_bilateral=imadjust(img_bilateral,[1/255 255/255],[0 1]);
figure; imshow(img_bilateral); title('Imagen suavizada con filtro bilateral y CLAHE mezclado');

%% --- 3: Segmentación con k-means en espacio YCbCr ---
k = 6;  % Número de clusters (losetas)
ycbcr_img = rgb2ycbcr(im2uint8(img_bilateral)); % imsegkmeans espera uint8 para rgb2ycbcr
L_kmeans = imsegkmeans(im2single(ycbcr_img), k);

figure; imshow(label2rgb(L_kmeans, 'jet', 'k'));
title('Segmentación inicial con k-means');

%% --- 4: Filtrado morfológico por cluster ---
umbral_area_min = 2500;  % Área mínima para filtrar objetos pequeños
se = strel('disk', 2);
L_filtrado = zeros(size(L_kmeans), 'like', L_kmeans);

for i = 1:k
    mask = (L_kmeans == i);
    mask = bwareaopen(mask, umbral_area_min);  % Eliminar regiones pequeñas
    mask = imdilate(mask, se);
    mask = imclose(mask, se);
    mask = imerode(mask, se);
    L_filtrado(mask) = i;
end

figure; imshow(label2rgb(L_filtrado, 'jet', 'k'));
title('Segmentación tras limpieza morfológica');

%% --- 5: Eliminar fondo (primer cluster dominante) ---
stats = regionprops(L_filtrado, 'Area', 'PixelIdxList');
[~, idx_max] = max([stats.Area]);
cluster_fondo = L_filtrado(stats(idx_max).PixelIdxList(1));
L_sin_fondo = L_filtrado;
L_sin_fondo(L_filtrado == cluster_fondo) = 0;

figure; imshow(label2rgb(L_sin_fondo, 'jet', 'k'));
title('Sin el primer fondo (negro o dominante)');

%% --- 6: Eliminar segundo fondo (borde/tablero) ---
stats = regionprops(L_sin_fondo, 'Area', 'PixelIdxList');
[~, idx_max] = max([stats.Area]);
cluster_fondo2 = L_sin_fondo(stats(idx_max).PixelIdxList(1));
L_sin_fondo2 = L_sin_fondo;
L_sin_fondo2(L_sin_fondo == cluster_fondo2) = 0;

figure; imshow(label2rgb(L_sin_fondo2, 'jet', 'k'));
title('Sin el segundo fondo (tablero u otro)');

%% --- 7: Rellenar huecos dentro de las losetas útiles ---
L_rellenado = zeros(size(L_sin_fondo2), 'like', L_sin_fondo2);
etiquetas = unique(L_sin_fondo2);
etiquetas(etiquetas == 0) = [];  % Omitir fondo

% Define aquí el elemento estructurante con el radio que mejor funcione
se = strel('disk', 2);   % prueba radios 1,2,3,… hasta que cierre bien el contorno

for i = 1:numel(etiquetas)
    mask = (L_sin_fondo2 == etiquetas(i));
    % 1) Cerrar pequeños orificios en el contorno
    mask_closed = imclose(mask, se);
    mask_rellenado = imfill(mask_closed, 'holes');
    L_rellenado(mask_rellenado) = etiquetas(i);
end

figure; imshow(label2rgb(L_rellenado, 'jet', 'k'));
title('Losetas útiles con huecos rellenados');
%% 8) Crear imagen donde solo estén las losetas segmentadas
mask = L_rellenado > 0;               % lógico: true en cada píxel de interés
img_final = zeros(size(img), 'like', img);

% Aplico la máscara canal a canal
for c = 1:size(img,3)
    canal = img(:,:,c);
    canal(~mask) = 0;
    img_final(:,:,c) = canal;
end

% Mostrar resultado
figure; imshow(img_final); title('Tablero extraído');

%% SEGMENTACIÓN Y DETECCIÓN DE LOS TIPOS DE TERRENO EN EL TABLERO
% Crear carpeta para las figuras si no existe
output_dir = 'figuras_informe';
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

% Variables para controlar la cantidad de losetas a detectar por tipo
num_pastos = 3;
num_bosques = 4;
num_cerro = 4;
num_montana = 3;
num_sembrado = 4;
num_desierto = 1;

% La imagen de entrada es directamente la salida anterior
I = im2double(img);
maskBoard = rgb2gray(I) > 0;
Iboard = I .* maskBoard;

% Inicializar máscaras y etiquetas
mask_detected = false(size(maskBoard));
label_map = zeros(size(maskBoard));
label_counter = 1;
label_summary = {};
I_actual = Iboard;

% Función para borrar zona completa y suavizar
borrarZonaCompleta = @(mask_final, mask_detected, I_actual) ...
    deal(imdilate(mask_final, strel('disk', 10)), ...
         imdilate(mask_final, strel('disk', 10)), ...
         borrarDirectamente(I_actual, imdilate(mask_final, strel('disk', 10))));

% Función para borrar directamente usando indexación lógica
function I_out = borrarDirectamente(I_in, mask)
    I_out = I_in;
    for c = 1:3
        temp = I_out(:,:,c);
        temp(mask) = 0;
        I_out(:,:,c) = temp;
    end
end

%% 1) PASTOS
labI = rgb2lab(I_actual); a = labI(:,:,2); b = labI(:,:,3);
mask_pasto = (a < -10) & (b > 25);
mask_pasto = imopen(mask_pasto, strel('disk', 3));
mask_pasto = imclose(mask_pasto, strel('disk', 5));
mask_pasto = imfill(mask_pasto, 'holes');
[L_pasto, ~] = bwlabel(mask_pasto); stats = regionprops(L_pasto, 'Area');
areas = [stats.Area]; [~, idx] = sort(areas, 'descend');
mask_pasto_final = false(size(mask_pasto));
for k = 1:min(num_pastos, numel(idx))
    mask = (L_pasto == idx(k)); mask_pasto_final = mask_pasto_final | mask;
    label_map(mask) = label_counter;
    label_summary{label_counter} = 'Pastos';
    label_counter = label_counter + 1;
end
figure; imshow(mask_pasto_final); title('Máscara final de pastos');
saveas(gcf, fullfile(output_dir, 'Figura_17_Mascara_pastos.png'));
[dilated_mask, dilated_detected, I_actual] = borrarZonaCompleta(mask_pasto_final, mask_detected, I_actual);
mask_pasto_final = dilated_mask; mask_detected = dilated_detected;
figure; imshow(I_actual); title('Imagen sin zonas de pastos');
saveas(gcf, fullfile(output_dir, 'Figura_18_Imagen_sin_pastos.png'));

%% 2) BOSQUES
labI = rgb2lab(I_actual); L = labI(:,:,1); a = labI(:,:,2); b = labI(:,:,3);
mask_bosque = (a < -2) & (b > 10) & (b < 25) & (L < 80);
mask_bosque = imopen(mask_bosque, strel('disk', 3));
mask_bosque = imclose(mask_bosque, strel('disk', 5));
mask_bosque = imfill(mask_bosque, 'holes');
[L_bosque, ~] = bwlabel(mask_bosque); stats = regionprops(L_bosque, 'Area');
areas = [stats.Area]; [~, idx] = sort(areas, 'descend');
mask_bosque_final = false(size(mask_bosque));
for k = 1:min(num_bosques, numel(idx))
    mask = (L_bosque == idx(k)); mask_bosque_final = mask_bosque_final | mask;
    label_map(mask) = label_counter;
    label_summary{label_counter} = 'Bosque';
    label_counter = label_counter + 1;
end
figure; imshow(mask_bosque_final); title('Máscara final de bosque');
saveas(gcf, fullfile(output_dir, 'Figura_19_Mascara_bosques.png'));
[dilated_mask, dilated_detected, I_actual] = borrarZonaCompleta(mask_bosque_final, mask_detected, I_actual);
mask_bosque_final = dilated_mask; mask_detected = dilated_detected;
figure; imshow(I_actual); title('Imagen sin zonas de bosques');
saveas(gcf, fullfile(output_dir, 'Figura_20_Imagen_sin_bosques.png'));

%% 3) CERRO
labI = rgb2lab(I_actual); L = labI(:,:,1); a = labI(:,:,2); b = labI(:,:,3);
mask_cerro = (a > -5) & (a < 10) & (b > -5) & (b < 10) & (L > 20) & (L < 85);
mask_cerro = imclose(mask_cerro, strel('disk', 8));
mask_cerro = imopen(mask_cerro, strel('disk', 4));
mask_cerro = imfill(mask_cerro, 'holes');
[L_cerro, ~] = bwlabel(mask_cerro); stats = regionprops(L_cerro, 'Area');
areas = [stats.Area]; [~, idx] = sort(areas, 'descend');
mask_cerro_final = false(size(mask_cerro));
for k = 1:min(num_cerro, numel(idx))
    mask = (L_cerro == idx(k)); mask_cerro_final = mask_cerro_final | mask;
    label_map(mask) = label_counter;
    label_summary{label_counter} = 'Cerro';
    label_counter = label_counter + 1;
end
figure; imshow(mask_cerro_final); title('Máscara final de Cerro');
saveas(gcf, fullfile(output_dir, 'Figura_21_Mascara_cerro.png'));
for c = 1:3, temp = I_actual(:,:,c); temp(mask_cerro_final) = 0; I_actual(:,:,c) = temp; end
figure; imshow(I_actual); title('Imagen sin zonas de Cerro');
saveas(gcf, fullfile(output_dir, 'Figura_22_Imagen_sin_cerro.png'));


%% 4) MONTAÑA
labI = rgb2lab(I_actual); L = labI(:,:,1); a = labI(:,:,2); b = labI(:,:,3);
mask_montana = (a > 10) & (a < 30) & (b > 15) & (b < 45) & (L > 30) & (L < 85);
mask_montana = imclose(mask_montana, strel('disk', 5));
mask_montana = imopen(mask_montana, strel('disk', 3));
mask_montana = imfill(mask_montana, 'holes');
[L_montana, ~] = bwlabel(mask_montana); stats = regionprops(L_montana, 'Area');
areas = [stats.Area]; [~, idx] = sort(areas, 'descend');
mask_montana_final = false(size(mask_montana));
for k = 1:min(num_montana, numel(idx)), mask = (L_montana == idx(k)); mask_montana_final = mask_montana_final | mask; label_map(mask) = label_counter; label_summary{label_counter} = 'Montaña'; label_counter = label_counter + 1; end
figure; imshow(mask_montana_final); title('Máscara final de Montaña');
saveas(gcf, fullfile(output_dir, 'Figura_23_Mascara_montana.png'));
for c = 1:3, temp = I_actual(:,:,c); temp(mask_montana_final) = 0; I_actual(:,:,c) = temp; end
figure; imshow(I_actual); title('Imagen sin zonas de Montaña');
saveas(gcf, fullfile(output_dir, 'Figura_24_Imagen_sin_montana.png'));

%% 5) SEMBRADO
labI = rgb2lab(I_actual); L = labI(:,:,1); a = labI(:,:,2); b = labI(:,:,3);
mask_cultivo = (L > 50) & (L < 70) & (a > -10) & (a < 20) & (b > 20) & (b < 75);
mask_cultivo = imclose(mask_cultivo, strel('disk', 6));
mask_cultivo = imopen(mask_cultivo, strel('disk', 3));
mask_cultivo = imfill(mask_cultivo, 'holes');
[L_cultivo, ~] = bwlabel(mask_cultivo); stats = regionprops(L_cultivo, 'Area');
areas = [stats.Area]; [~, idx] = sort(areas, 'descend');
mask_cultivo_final = false(size(mask_cultivo));
for k = 1:min(num_sembrado, numel(idx)), mask = (L_cultivo == idx(k)); mask_cultivo_final = mask_cultivo_final | mask; label_map(mask) = label_counter; label_summary{label_counter} = 'Sembrado'; label_counter = label_counter + 1; end
figure; imshow(mask_cultivo_final); title('Máscara final de SEMBRADO');
saveas(gcf, fullfile(output_dir, 'Figura_25_Mascara_sembrado.png'));
for c = 1:3, temp = I_actual(:,:,c); temp(mask_cultivo_final) = 0; I_actual(:,:,c) = temp; end
figure; imshow(I_actual); title('Imagen final sin zonas de SEMBRADO');
saveas(gcf, fullfile(output_dir, 'Figura_26_Imagen_sin_sembrado.png'));

%% 6) DESIERTO
labI = rgb2lab(I_actual); L = labI(:,:,1); a = labI(:,:,2); b = labI(:,:,3);
mask_desierto = (L > 20) & (L < 70) & (a > -10) & (a < 10) & (b > 10) & (b < 40);
mask_desierto = imopen(mask_desierto, strel('disk', 2));
[L_desierto, ~] = bwlabel(mask_desierto); stats = regionprops(L_desierto, 'Area');
areas = [stats.Area]; [~, idx_max] = max(areas);
mask_desierto_final = false(size(mask_desierto));
if ~isempty(idx_max), mask = (L_desierto == idx_max); mask_desierto_final = mask_desierto_final | mask; label_map(mask) = label_counter; label_summary{label_counter} = 'Desierto'; label_counter = label_counter + 1; end
figure; imshow(mask_desierto_final); title('Máscara final de DESIERTO');
saveas(gcf, fullfile(output_dir, 'Figura_27_Mascara_desierto.png'));
for c = 1:3, temp = I_actual(:,:,c); temp(mask_desierto_final) = 0; I_actual(:,:,c) = temp; end
figure; imshow(I_actual); title('Imagen final sin zona de DESIERTO');
saveas(gcf, fullfile(output_dir, 'Figura_28_Imagen_sin_desierto.png'));

%% VISUALIZACIÓN FINAL
figure; imshow(I); hold on; stats_final = regionprops(label_map, 'Centroid');
for k = 1:numel(stats_final), c = stats_final(k).Centroid; text(c(1), c(2), num2str(k), 'Color', 'w', 'FontSize', 10, 'FontWeight', 'bold', 'HorizontalAlignment', 'center'); end
title('Zonas identificadas y numeradas en la imagen original'); hold off;
saveas(gcf, fullfile(output_dir, 'Figura_29_Zonas_etiquetadas.png'));

figure; imshow(I_actual); title('Imagen final con zonas eliminadas (uniforme y completa)');
saveas(gcf, fullfile(output_dir, 'Figura_30_Imagen_final.png'));

disp('===== TODAS LAS FIGURAS GUARDADAS CORRECTAMENTE EN LA CARPETA =====');

% Imprimir resumen final en consola
fprintf('\n===== RESUMEN FINAL DE LOS DETECTADOS =====\n');
for k = 1:length(label_summary)
    fprintf('Zona %d: %s\n', k, label_summary{k});
end
disp('===========================================');
