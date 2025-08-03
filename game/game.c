#include "raylib/raylib.h"
#include <math.h>
#include <string.h>

typedef struct {
  Rectangle rect;
  float dy;
} Player;

#define DEFINE_LIST(type, name, max_count)                                     \
  typedef struct {                                                             \
    type items[max_count];                                                     \
    int count;                                                                 \
    int capacity;                                                              \
  } name

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

    Vector2 mouseInScreen = GetMousePosition();
    Vector2 mouseInWorld = GetScreenToWorld2D(mouseInScreen, game.camera);
    // handle editor controls
    Vector2 mouseTilePos = {.x = roundf(mouseInWorld.x),
                            .y = roundf(mouseInWorld.y)};
    {
      if (IsMouseButtonDown(MOUSE_BUTTON_LEFT)) {
        // check if tile already exists
        bool tileExists = false;
        for (int i = 0; i < game.tiles.count; i++) {
          Tile tile = game.tiles.items[i];
          if (tile.x == mouseTilePos.x && tile.y == mouseTilePos.y) {
            tileExists = true;
            break;
          }
        }
        // add tile
        if (tileExists == false && game.tiles.count < game.tiles.capacity) {
          Tile newTile = {mouseTilePos.x, mouseTilePos.y};
          game.tiles.items[game.tiles.count++] = newTile;
        }
      }

      if (IsMouseButtonDown(MOUSE_BUTTON_RIGHT)) {
        // remove tile
        for (int i = 0; i < game.tiles.count; i++) {
          Tile tile = game.tiles.items[i];
          if (tile.x == mouseTilePos.x && tile.y == mouseTilePos.y) {
            memmove(&game.tiles.items[i], &game.tiles.items[i + 1],
                    (game.tiles.count - i - 1) * sizeof(Tile));
            game.tiles.count--;
            break;
          }
        }
      }
    }

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
        game.zoomFactor += zoomSpeed * 2 * deltaTime;
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
        game.camera.target = (Vector2){
            game.player.rect.x,
            game.player.rect.y,
        };
      }
    }

    BeginDrawing();
    ClearBackground(RAYWHITE);
    BeginMode2D(game.camera);
    {

      // draw tiles
      for (int i = 0; i < game.tiles.count; i++) {
        Tile tile = game.tiles.items[i];
        DrawRectanglePro((Rectangle){tile.x, tile.y, 1.0f, 1.0f},
                         (Vector2){0.5f, 0.5f}, 0.0f, GREEN);
      }

      DrawRectanglePro(game.player.rect,
                       (Vector2){game.player.rect.width / 2.0f,
                                 game.player.rect.height / 2.0f},
                       0.0f, BLUE);

      // draw cursor
      DrawRectangleLinesEx(
          (Rectangle){mouseTilePos.x - .5f, mouseTilePos.y - .5, 1.0f, 1.0f},
          0.1f, RED);
    }

    EndMode2D();
    DrawTextEx(fontTtf, TextFormat("FPS: %d", GetFPS()), (Vector2){10, 10},
               (float)fontTtf.baseSize / dpi.x, 2, DARKGRAY);
    DrawTextEx(fontTtf, TextFormat("Zoom: %.2f", game.zoomFactor),
               (Vector2){10, 10 + 30 * 1}, (float)fontTtf.baseSize / dpi.x, 2,
               DARKGRAY);
    DrawTextEx(fontTtf,
               TextFormat("Mouse pos: %f, %f", mouseInWorld.x, mouseInWorld.y),
               (Vector2){10, 10 + 30 * 2}, (float)fontTtf.baseSize / dpi.x, 2,
               DARKGRAY);
    DrawTextEx(fontTtf,
               TextFormat("Tile pos: %f, %f", mouseTilePos.x, mouseTilePos.y),
               (Vector2){10, 10 + 30 * 3}, (float)fontTtf.baseSize / dpi.x, 2,
               DARKGRAY);

    EndDrawing();
  }
  CloseWindow();

  return 0;
}
