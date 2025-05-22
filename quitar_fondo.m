%% Preprocesamiento para la extracción del tablero
clear; close all; clc;
% Cargar imagen
imagen = imread('imgs/catan 2.jpeg'); 
figure;imshow(imagen);title('Imagen original');

imagen_double = im2double(imagen);

% Suavizar con filtro bilateral para reducir reflejos duros
imagen_suave = imbilatfilt(imagen_double, 0.1, 5); 

figure; imshow(imagen_suave);title('Imagen suave');

%% Convertir a Lab y aplicar k-means
lab = rgb2lab(imagen_suave);
L = imsegkmeans(single(lab), 2, 'NumAttempts', 5);
[m, n, ~] = size(imagen);

% Identificar cluster central
centro = L(round(m/3):round(2*m/3), round(n/3):round(2*n/3));
modo = mode(centro(:));
mascara_tablero = L == modo;

%% Crear lista de etapas
etapas = cell(1, 9);
titulos = {
    '1. Imagen original', 
    '2. K-means (2 clusters)', 
    '3. Máscara inicial', 
    '4. Huecos rellenados', 
    '5. Quitar regiones pequeñas', 
    '6. Cierre morfológico', 
    '7. Mayor componente', 
    '8. Suavizado (open/close)', 
    '9. Erosión final'
};

% Guardar cada etapa
etapas{1} = imagen;
etapas{2} = label2rgb(L);
etapas{3} = mascara_tablero;

% Paso 1: Rellenar huecos
mascara_tablero = imfill(mascara_tablero, 'holes');
etapas{4} = mascara_tablero;

% Paso 2: Quitar regiones pequeñas
mascara_tablero = bwareaopen(mascara_tablero, 8000);
etapas{5} = mascara_tablero;

% Paso 3: Cierre morfológico
se = strel('disk', 20);
mascara_tablero = imclose(mascara_tablero, se);
etapas{6} = mascara_tablero;

% Paso 4: Conservar solo el componente más grande
mascara_tablero = bwareafilt(mascara_tablero, 1);
etapas{7} = mascara_tablero;

% Paso 5: Suavizado morfológico (open + close)
se = strel('disk', 30);
mascara_tablero = imopen(mascara_tablero, se);
mascara_tablero = imclose(mascara_tablero, se);
etapas{8} = mascara_tablero;

% Paso 6: Erosión final
se = strel('disk', 25);
mascara_tablero = imerode(mascara_tablero, se);
etapas{9} = mascara_tablero;

% Mostrar todas las etapas
figure('Name','Etapas del preprocesamiento del tablero','Position',[100 100 1400 700]);
for i = 1:9
    subplot(3,3,i);
    imshow(etapas{i});
    title(titulos{i}, 'FontSize', 10);
end


%%
% Aplicar la máscara a la imagen original
imagen_segmentada = imagen; % Copia original

% Poner a negro el fondo (fuera del tablero)
for c = 1:3
    canal = imagen_segmentada(:,:,c);
    canal(~mascara_tablero) = 0;
    imagen_segmentada(:,:,c) = canal;
end

% Mostrar imagen segmentada
figure;
imshow(imagen_segmentada);
title('Imagen original con solo el tablero');
imwrite(imagen_segmentada,"hola.png")

