#include "raylib/raylib.h"

#include <stdio.h>

typedef struct {
  Rectangle rect;
  float dy;
} Player;

typedef struct {
  Player player;
  Camera2D camera;
  float zoomFactor;
} Game;

int main(void) {
  const int screenWidth = 400;
  const int screenHeight = 400;

  SetConfigFlags(FLAG_WINDOW_RESIZABLE);
  InitWindow(screenWidth, screenHeight, "raylib [core] example - basic window");
  const Vector2 dpi = GetWindowScaleDPI();
  const int fontSize = 20 * dpi.x;
  Font fontTtf = LoadFontEx("resources/IBMPlexMono.ttf", fontSize, 0, 250);

  Game game = {
      .player =
          {
              .rect = {0, 0, .8, 1.4},
              .dy = 0,
          },
      .camera =
          {
              .offset =
                  {
                      screenWidth / 2.0f,
                      screenHeight / 2.0f,
                  },
              .target = {0, 0},
              .rotation = 0.0f,
              .zoom = 1.0f,
          },
      .zoomFactor = 1.0f,
  };

  double lastFrameTime = GetTime();
  int frameCounter = 0;
  while (!WindowShouldClose()) {
    const double currentFrameTime = GetTime();
    const double deltaTime = currentFrameTime - lastFrameTime;
    lastFrameTime = currentFrameTime;

    const float defaultGameWidth = 10;
    const float defaultGameHeight = 10;

    {
      float speed = 10;
      if (IsKeyDown(KEY_LEFT) || IsKeyDown(KEY_A)) {
        game.player.rect.x -= speed * deltaTime;
      }
      if (IsKeyDown(KEY_RIGHT) || IsKeyDown(KEY_D)) {
        game.player.rect.x += speed * deltaTime;
      }
      if (IsKeyDown(KEY_UP) || IsKeyDown(KEY_W)) {
        game.player.rect.y -= speed * deltaTime;
      }
      if (IsKeyDown(KEY_DOWN) || IsKeyDown(KEY_S)) {
        game.player.rect.y += speed * deltaTime;
      }

      float zoomSpeed = 0.5f;
      if (IsKeyDown(KEY_EQUAL)) {
        game.zoomFactor += zoomSpeed * deltaTime;
      }
      if (IsKeyDown(KEY_MINUS)) {
        game.zoomFactor -= zoomSpeed * deltaTime;
      }
      game.camera.zoom =
          (float)screenWidth / defaultGameWidth * game.zoomFactor;
    }

    BeginDrawing();

    ClearBackground(RAYWHITE);

    BeginMode2D(game.camera);
    {
      DrawRectanglePro(game.player.rect,
                       (Vector2){game.player.rect.width / 2.0f,
                                 game.player.rect.height / 2.0f},
                       0.0f, BLUE);

      DrawRectanglePro((Rectangle){-100, 100, game.player.rect.width,
                                   game.player.rect.height},
                       (Vector2){game.player.rect.width / 2.0f,
                                 game.player.rect.height / 2.0f},
                       0.0f, Fade(GRAY, 0.5f));
    }
    EndMode2D();

    DrawTextEx(fontTtf, "hello world\nwow", (Vector2){20.0f, 100.0f},
               (float)fontTtf.baseSize / dpi.x, 2, GRAY);

    DrawText(TextFormat("FPS: %d", GetFPS()), 10, 10, 20, DARKGRAY);
    DrawText(TextFormat("ZOOM: %.2f", game.camera.zoom), 10, 40, 20, DARKGRAY);
    EndDrawing();
  }

  CloseWindow();

  return 0;
}
