clc; clear; close all;

figure('Name', 'Extracción del tablero (fondo eliminado)', 'Position', [100 100 1400 700]);

for idx = 1:10
    %% --- 1: Cargar imagen y suavizar ---
    img = imread(sprintf('imgs2/catan %d.jpeg', idx));
    img_double = im2double(img);
    img_suave = imbilatfilt(img_double, 0.1, 5); 

    %% --- 2: Extraer el tablero con k-means ---
    lab = rgb2lab(img_suave);
    L_board = imsegkmeans(single(lab), 2, 'NumAttempts', 5);
    [m, n, ~] = size(img);
    centro = L_board(round(m/3):round(2*m/3), round(n/3):round(2*n/3));
    modo = mode(centro(:));
    mascara_tablero = L_board == modo;

    %% --- 3: Limpiar la máscara del tablero ---
    mascara_tablero = imfill(mascara_tablero, 'holes');
    mascara_tablero = bwareaopen(mascara_tablero, 8000);
    mascara_tablero = imclose(mascara_tablero, strel('disk', 20));
    mascara_tablero = bwareafilt(mascara_tablero, 1);
    se_suavizar = strel('disk', 30);
    mascara_tablero = imopen(mascara_tablero, se_suavizar);
    mascara_tablero = imclose(mascara_tablero, se_suavizar);
    mascara_tablero = imerode(mascara_tablero, strel('disk', 25));

    %% --- 4: Aplicar máscara para quitar fondo ---
    img_tablero = img;
    for c = 1:3
        canal = img_tablero(:,:,c);
        canal(~mascara_tablero) = 0;
        img_tablero(:,:,c) = canal;
    end

    %% --- 5: Visualizar ---
    subplot(2, 5, idx);
    imshow(img_tablero);
    title(sprintf('Catan %d', idx), 'FontSize', 10);
end
