#include "raylib/raylib.h"
#include <math.h>
#include <stdbool.h>
#include <string.h>

#include "microui/microui.c"
#include "microui/microui.h"
#include "murl.c"
#include "murl.h"

typedef struct {
  Rectangle rect;
  float dy;
  bool triedJump;
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
  bool editing;

  double physicsTimeAccumulator; // for physics updates

  bool showDebugUI;  // toggle debug UI
  bool showSecondUI; // toggle second UI
} Game;

const int PHYSIC_HZ = 500;

bool isColliding(Rectangle rec1, Rectangle rec2) {
  // positions are the center of the rectangle
  float rec1HalfWidth = rec1.width / 2.0f;
  float rec1HalfHeight = rec1.height / 2.0f;
  float rec2HalfWidth = rec2.width / 2.0f;
  float rec2HalfHeight = rec2.height / 2.0f;
  return (rec1.x - rec1HalfWidth < rec2.x + rec2HalfWidth &&
          rec1.x + rec1HalfWidth > rec2.x - rec2HalfWidth &&
          rec1.y - rec1HalfHeight < rec2.y + rec2HalfHeight &&
          rec1.y + rec1HalfHeight > rec2.y - rec2HalfHeight);
}

const int fontSize = 12;

int main(void) {
  const int initScreenWidth = 600;
  const int initScreenHeight = 600;
  SetConfigFlags(FLAG_WINDOW_RESIZABLE | FLAG_WINDOW_HIGHDPI);
  InitWindow(initScreenWidth, initScreenHeight, "platformer");
  const Vector2 dpi = GetWindowScaleDPI();

  Font monoFont =
      LoadFontEx("resources/IBMPlexMono.ttf", fontSize * dpi.x, 0, 250);
  Font sansFont =
      LoadFontEx("resources/IBMPlexSans.ttf", fontSize * dpi.x, 0, 250);

  mu_Context *muCtx = malloc(sizeof(mu_Context));
  mu_init(muCtx);
  murl_setup_font_ex(muCtx, &sansFont);

  Game game = {
      .player =
          {
              .rect = {0, 0, .8, 1.2},
              .dy = 0,
              .triedJump = false,
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
      .editing = true,
      .showDebugUI = false,
      .showSecondUI = false,
  };

  double lastFrameTime = GetTime();
  int frameCounter = 0;
  while (!WindowShouldClose()) {
    Vector2 mouseInScreen = GetMousePosition();
    murl_handle_input(muCtx);
    mu_begin(muCtx);

    if (game.showDebugUI) {
      int opt = MU_OPT_NOCLOSE;
      if (mu_begin_window_ex(muCtx, "Demo Window", mu_rect(40, 40, 300, 450),
                             opt)) {
        mu_Container *win = mu_get_current_container(muCtx);
        win->rect.w = mu_max(win->rect.w, 240);
        win->rect.h = mu_max(win->rect.h, 300);

        /* window info */
        if (mu_header(muCtx, "Window Info")) {
          mu_Container *win = mu_get_current_container(muCtx);
          char buf[64];
          mu_layout_row(muCtx, 2, (int[]){54, -1}, 0);
          mu_label(muCtx, "Position:");
          sprintf(buf, "%d, %d", win->rect.x, win->rect.y);
          mu_label(muCtx, buf);
          mu_label(muCtx, "Size:");
          sprintf(buf, "%d, %d", win->rect.w, win->rect.h);
          mu_label(muCtx, buf);
        }

        /* labels + buttons */
        if (mu_header_ex(muCtx, "Test Buttons", MU_OPT_EXPANDED)) {
          mu_layout_row(muCtx, 3, (int[]){86, -110, -1}, 0);
          mu_label(muCtx, "Test buttons 1:");
          if (mu_button(muCtx, "Button 1")) {
            // write_log("Pressed button 1");
          }
          if (mu_button(muCtx, "Button 2")) {
            // write_log("Pressed button 2");
          }
          mu_label(muCtx, "Test buttons 2:");
          if (mu_button(muCtx, "Button 3")) {
            // write_log("Pressed button 3");
          }
          if (mu_button(muCtx, "Popup")) {
            mu_open_popup(muCtx, "Test Popup");
          }
          if (mu_begin_popup(muCtx, "Test Popup")) {
            mu_button(muCtx, "Hello");
            mu_button(muCtx, "World");
            mu_end_popup(muCtx);
          }
        }

        /* tree */
        if (mu_header_ex(muCtx, "Tree and Text", MU_OPT_EXPANDED)) {
          mu_layout_row(muCtx, 2, (int[]){140, -1}, 0);
          mu_layout_begin_column(muCtx);
          if (mu_begin_treenode(muCtx, "Test 1")) {
            if (mu_begin_treenode(muCtx, "Test 1a")) {
              mu_label(muCtx, "Hello");
              mu_label(muCtx, "world");
              mu_end_treenode(muCtx);
            }
            if (mu_begin_treenode(muCtx, "Test 1b")) {
              if (mu_button(muCtx, "Button 1")) {
                // write_log("Pressed button 1");
              }
              if (mu_button(muCtx, "Button 2")) {
                // write_log("Pressed button 2");
              }
              mu_end_treenode(muCtx);
            }
            mu_end_treenode(muCtx);
          }
          if (mu_begin_treenode(muCtx, "Test 2")) {
            mu_layout_row(muCtx, 2, (int[]){54, 54}, 0);
            if (mu_button(muCtx, "Button 3")) {
              // write_log("Pressed button 3");
            }
            if (mu_button(muCtx, "Button 4")) {
              // write_log("Pressed button 4");
            }
            if (mu_button(muCtx, "Button 5")) {
              // write_log("Pressed button 5");
            }
            if (mu_button(muCtx, "Button 6")) {
              // write_log("Pressed button 6");
            }
            mu_end_treenode(muCtx);
          }
          if (mu_begin_treenode(muCtx, "Test 3")) {
            static int checks[3] = {1, 0, 1};
            mu_checkbox(muCtx, "Checkbox 1", &checks[0]);
            mu_checkbox(muCtx, "Checkbox 2", &checks[1]);
            mu_checkbox(muCtx, "Checkbox 3", &checks[2]);
            mu_end_treenode(muCtx);
          }
          mu_layout_end_column(muCtx);

          mu_layout_begin_column(muCtx);
          mu_layout_row(muCtx, 1, (int[]){-1}, 0);
          mu_text(muCtx, "Lorem ipsum dolor sit amet, consectetur adipiscing "
                         "elit. Maecenas lacinia, sem eu lacinia molestie, mi "
                         "risus faucibus "
                         "ipsum, eu varius magna felis a nulla.");
          mu_layout_end_column(muCtx);
        }

        if (mu_button(muCtx, "open another window")) {
          game.showSecondUI = true;
        }

        mu_end_window(muCtx);

        if (game.showSecondUI) {
          if (mu_begin_window(muCtx, "Second Window",
                              mu_rect(100, 100, 300, 200))) {
            mu_layout_row(muCtx, 1, (int[]){-1}, 0);
            mu_label(muCtx, "This is a second window");
            mu_end_window(muCtx);
          } else {
            game.showSecondUI = false;
          }
        }
      }
    }

    mu_end(muCtx);

    const double currentFrameTime = GetTime();
    const double deltaTime = currentFrameTime - lastFrameTime;
    lastFrameTime = currentFrameTime;

    Vector2 mouseInWorld = GetScreenToWorld2D(mouseInScreen, game.camera);
    // handle editor controls
    Vector2 mouseTilePos = {.x = roundf(mouseInWorld.x),
                            .y = roundf(mouseInWorld.y)};

    if (IsKeyPressed(KEY_P)) {
      game.showDebugUI = !game.showDebugUI;
    }

    if (game.editing) {
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

      if (!muCtx->hover_root) {
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
    }

    if (!game.editing) {
      if (IsKeyPressed(KEY_SPACE) || IsKeyPressed(KEY_UP) ||
          IsKeyPressed(KEY_W)) {
        game.player.triedJump = true;
      }

      game.physicsTimeAccumulator += deltaTime;
      const float physicTick = 1.0f / PHYSIC_HZ;
      while (game.physicsTimeAccumulator >= physicTick) {
        game.physicsTimeAccumulator -= physicTick;

        float extraRepel = 0.0001f; // small value to avoid collision issues
        // handle movement and collisions in X axis
        {
          float playerDx = 0;
          float playerSpeed = 5.0f;
          if (IsKeyDown(KEY_LEFT) || IsKeyDown(KEY_A)) {
            playerDx = -playerSpeed * physicTick; // move left
            game.player.rect.x += playerDx;
          }
          if (IsKeyDown(KEY_RIGHT) || IsKeyDown(KEY_D)) {
            playerDx = playerSpeed * physicTick; // move right
            game.player.rect.x += playerDx;
          }

          for (int i = 0; i < game.tiles.count; i++) {
            Tile tile = game.tiles.items[i];
            Rectangle tileRect = (Rectangle){tile.x, tile.y, 1.0f, 1.0f};
            if (isColliding(game.player.rect, tileRect)) {
              float yOverlap =
                  game.player.rect.y > tileRect.y
                      ? (game.player.rect.y + game.player.rect.height / 2.0f) -
                            (tileRect.y - tileRect.height / 2.0f)
                      : (tileRect.y + tileRect.height / 2.0f) -
                            (game.player.rect.y -
                             game.player.rect.height / 2.0f);

              if (playerDx > 0) {
                game.player.rect.x = tileRect.x - (tileRect.width / 2.0f) -
                                     (game.player.rect.width / 2.0f) -
                                     extraRepel;
              } else {
                game.player.rect.x = tileRect.x + tileRect.width / 2.0f +
                                     game.player.rect.width / 2.0f + extraRepel;
              }
            }
          }
        }
        // handle movement and collisions in Y axis
        {
          // apply gravity
          game.player.dy += 9.81f * 2.0f * physicTick;
          if (game.player.triedJump) {
            game.player.dy = -10.0f; // jump speed
            game.player.triedJump = false;
          }
          float playerDy = game.player.dy * physicTick;
          game.player.rect.y += playerDy;
          for (int i = 0; i < game.tiles.count; i++) {
            Tile tile = game.tiles.items[i];
            Rectangle tileRect = (Rectangle){tile.x, tile.y, 1.0f, 1.0f};
            if (isColliding(game.player.rect, tileRect)) {
              if (playerDy > 0) {
                game.player.rect.y = tileRect.y - (tileRect.height / 2.0f) -
                                     (game.player.rect.height / 2.0f) -
                                     extraRepel;
                game.player.dy = 0; // stop falling
              } else {
                game.player.rect.y = tileRect.y + tileRect.height / 2.0f +
                                     game.player.rect.height / 2.0f +
                                     extraRepel;
                game.player.dy = 0; // stop jumping
              }
            }
          }
        }
      }
    }

    {
      if (IsKeyPressed(KEY_E)) {
        game.editing = !game.editing;
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

      if (game.editing) {
        // draw cursor
        DrawRectangleLinesEx(
            (Rectangle){mouseTilePos.x - .5f, mouseTilePos.y - .5, 1.0f, 1.0f},
            0.1f, RED);
      }
    }

    EndMode2D();
    DrawTextEx(monoFont, TextFormat("FPS: %d", GetFPS()), (Vector2){10, 10},
               (float)monoFont.baseSize / dpi.x, 2, DARKGRAY);
    DrawTextEx(monoFont, TextFormat("Zoom: %.2f", game.zoomFactor),
               (Vector2){10, 10 + 30 * 1}, (float)monoFont.baseSize / dpi.x, 2,
               DARKGRAY);
    DrawTextEx(monoFont,
               TextFormat("Mouse pos: %f, %f", mouseInWorld.x, mouseInWorld.y),
               (Vector2){10, 10 + 30 * 2}, (float)monoFont.baseSize / dpi.x, 2,
               DARKGRAY);
    DrawTextEx(monoFont,
               TextFormat("Tile pos: %f, %f", mouseTilePos.x, mouseTilePos.y),
               (Vector2){10, 10 + 30 * 3}, (float)monoFont.baseSize / dpi.x, 2,
               DARKGRAY);

    murl_render(muCtx);
    EndDrawing();
  }
  CloseWindow();

  return 0;
}
