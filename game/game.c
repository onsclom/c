#include "raylib/raylib.h"
#include <stddef.h>

#define DEFINE_LIST(type, name, max_count)                                     \
  typedef struct {                                                             \
    type items[max_count];                                                     \
    int count;                                                                 \
    int capacity;                                                              \
  } name

typedef struct {
  Rectangle rect;
  float dy;
} Player;

typedef struct {
  // width and height always 1
  int x;
  int y;
} Tile;

#define TILE_LIST_CAPACITY 1000
DEFINE_LIST(Tile, TileList, TILE_LIST_CAPACITY);

typedef struct {
  Player player;
  Camera2D camera;
  float zoomFactor;
  TileList tiles;
} Game;

TileList tiles = {0};

int main(void) {
  const int initScreenWidth = 600;
  const int initScreenHeight = 600;
  SetConfigFlags(FLAG_WINDOW_RESIZABLE);
  InitWindow(initScreenWidth, initScreenHeight, "platformer");
  const Vector2 dpi = GetWindowScaleDPI();
  const int fontSize = 20 * dpi.x;
  Font fontTtf = LoadFontEx("resources/IBMPlexMono.ttf", fontSize, 0, 250);

  Game game = {
      .player =
          {
              .rect = {0, 0, .8, 1.2},
              .dy = 0,
          },
      .camera =
          {
              .offset =
                  {
                      initScreenWidth / 2.0f,
                      initScreenHeight / 2.0f,
                  },
              .target = {0, 0},
              .rotation = 0.0f,
              .zoom = 1.0f,
          },
      .zoomFactor = 1.0f,
      .tiles = {0, .capacity = TILE_LIST_CAPACITY},
  };

  double lastFrameTime = GetTime();
  int frameCounter = 0;
  while (!WindowShouldClose()) {
    const double currentFrameTime = GetTime();
    const double deltaTime = currentFrameTime - lastFrameTime;
    lastFrameTime = currentFrameTime;

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

      {
        const float defaultGameWidth = 20;
        const int screenWidth = GetScreenWidth();
        const int screenHeight = GetScreenHeight();
        game.camera.offset = (Vector2){screenWidth / 2.0f, screenHeight / 2.0f};
        game.camera.zoom =
            (float)screenWidth / defaultGameWidth * game.zoomFactor;
        game.camera.target = (Vector2){0, 0};
      }
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

    // get mouse position in world coordinates
    Vector2 mousePosition = GetMousePosition();
    Vector2 mouseInCamera = GetScreenToWorld2D(mousePosition, game.camera);
    // draw a circle at the mouse position
    DrawCircleV(mouseInCamera, 1, RED);

    EndMode2D();
    DrawTextEx(fontTtf, "hello world\nwow", (Vector2){20.0f, 100.0f},
               (float)fontTtf.baseSize / dpi.x, 2, GRAY);
    DrawText(TextFormat("FPS: %d", GetFPS()), 10, 10, 20, DARKGRAY);
    DrawText(TextFormat("ZOOM: %.2f", game.zoomFactor), 10, 40, 20, DARKGRAY);

    EndDrawing();
  }
  CloseWindow();

  return 0;
}
