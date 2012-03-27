import toxi.color.*;
import toxi.color.theory.*;

import toxi.data.csv.*;
import toxi.data.feeds.*;
import toxi.data.feeds.util.*;

import processing.opengl.*;

import toxi.processing.*;

import toxi.physics3d.*;
import toxi.physics2d.constraints.*;
import toxi.physics2d.behaviors.*;
import toxi.physics3d.constraints.*;
import toxi.physics2d.*;
import toxi.physics3d.behaviors.*;

import toxi.math.conversion.*;
import toxi.geom.*;
import toxi.math.*;
import toxi.geom.mesh2d.*;
import toxi.geom.nurbs.*;
import toxi.util.datatypes.*;
import toxi.util.events.*;
import toxi.geom.mesh.subdiv.*;
import toxi.math.waves.*;
import toxi.geom.mesh.*;
import toxi.util.*;
import toxi.math.noise.*;

final int RESX = 40;
final int RESY = 30;
final int TWEET_DELAY = 50;

final int BOX_X_SIZE = 5;
final int BOX_Y_SIZE = 5;
final int BOX_Z_SIZE = 5;

final int PLUCK_STRENGTH = 10;
final float STIFFNESS = 0.5;

boolean ONLINE = false;
final String QUERY = "resonate_io";

VerletPhysics3D physics;
ToxiclibsSupport gfx;

List<TweetPoint> tweets = new ArrayList<TweetPoint>();
TweetPoint selection = null;
int tweetId;
int progress;

float scaleX;
float scaleY;

void setup() {
  size(1200, 800, OPENGL);
  background(0);
  noStroke();

  physics = new VerletPhysics3D();
  gfx = new ToxiclibsSupport(this);

  scaleX = (float) width / (RESX - 1);
  scaleY = (float) height / (RESY - 1);

  for (int y = 0; y < RESY; y++) {
    for (int x = 0; x < RESX; x++) {
      // create a particle
      VerletParticle3D p = new VerletParticle3D(new Vec3D(x - RESX / 2, y - RESY / 2, 0).scaleSelf(scaleX, scaleY, 1));
      physics.addParticle(p);

      if (x > 0) {
        // add a horizontal connection
        VerletParticle3D q = physics.particles.get(index(x - 1, y));
        VerletSpring3D s = new VerletSpring3D(p, q, p.distanceTo(q), STIFFNESS);
        physics.addSpring(s);
      }

      if (y > 0) {
        // add a vertical connection
        VerletParticle3D q = physics.particles.get(index(x, y - 1));
        VerletSpring3D s = new VerletSpring3D(p, q, p.distanceTo(q), STIFFNESS);
        physics.addSpring(s);
      }
    }
  }

  // lock corners
  physics.particles.get(index(0, 0)).lock();
  physics.particles.get(index(RESX - 1, 0)).lock();
  physics.particles.get(index(RESX - 1, RESY - 1)).lock();
  physics.particles.get(index(0, RESY - 1)).lock();

  initTwitter();
}

void draw() {
  hint(ENABLE_DEPTH_TEST);
  
  background(0);
  // fade
//  fill(0, 20);
//  rect(0, 0, width, height);
//  fill(255);
  
  pushMatrix();
  translate(width/2, height/2, 0);
  rotateX(radians(60));

  //  randomJitter();

  progress++;
  if (progress == TWEET_DELAY) {
    progress = 0;
    if (tweetId < tweets.size() - 1) {
      tweetId++;
      jitterGrid(tweets.get(tweetId).pos);
    }
  }

  // update physics
  physics.update();

  // draw springs
  stroke(255);
  for (VerletSpring3D s : physics.springs) {
    gfx.line(s.a, s.b);
  }

  // draw particles
  int c = 0;
  noStroke();
  for (VerletParticle3D p : physics.particles) {
    //    stroke(c % 255, 255 - c % 255, 255);
    //    fill(c % 255, 255 - c % 255, 255);
    //    fill(c % 255, 255 - c % 255, 255 - (((int)abs(p.z) * 4) % 255));
    gfx.fill(TColor.newHSV(map(p.z, -50, 50, 0, 1), 1, 1));
//    gfx.fill(TColor.newHSV(0.58, map(p.z, -50, 50, 0, 1), 1));
    gfx.box(new AABB(p, new Vec3D(BOX_X_SIZE, BOX_Y_SIZE, BOX_Z_SIZE)));
    c++;
  }

  // draw tweets
  fill(255, 0, 0);
  for (int i = 0; i <= tweetId; i++) {
    TweetPoint tp = tweets.get(i);

    // find related particle for tweet
    int idx = index((int)tp.pos.x + RESX / 2, (int)tp.pos.y + RESY / 2);

    // offset z position
    Vec3D pos = physics.particles.get(idx).add(0, 0, 10);

    // check if a tweet is selected
    if (selection != null && selection == tp) {
      gfx.fill(TColor.YELLOW);
    }
    else {
      gfx.fill(TColor.RED);
    }

    // draw as sphere
    gfx.sphere(new Sphere(pos, 8), 10);
    text(tp.tweet.author.name, pos.x, pos.y - 10);
  }

  // handle mouse
  handleMouseMoved();

  // back to 2D
  popMatrix();

  hint(DISABLE_DEPTH_TEST);
  if (selection != null) {
    String txt = selection.tweet.title;
    fill(0, 200);
    float h = textWidth(txt) / 200 * 48;
    rect(mouseX - 10, mouseY - 10, 220, h);
    fill(255);
    text(txt, mouseX, mouseY, 200, 1000);
  }
}

int index(int x, int y) {
  return y * RESX + x;
}

void randomJitter() {
  if (MathUtils.randomChance(0.5)) {
    physics.particles.get((int)random(RESX * RESY)).jitter(50);
    //    tweets.get((int)random(tweets.size())).pos.jitter(50);
  }
}

void jitterGrid(Vec2D gp) {
  int idx = index((int)gp.x + RESX / 2, (int)gp.y + RESY / 2);
  physics.particles.get(idx).jitter(PLUCK_STRENGTH);
}

void handleMouseMoved() {
  Vec2D mpos = new Vec2D(mouseX, mouseY);
  for (int i = 0; i <= tweetId; i++) {
    TweetPoint tp = tweets.get(i);
    int idx = index((int)tp.pos.x + RESX / 2, (int)tp.pos.y + RESY / 2);
    Vec3D pos = physics.particles.get(idx);
    float sx = screenX(pos.x, pos.y, pos.z);
    float sy = screenY(pos.x, pos.y, pos.z);
    Vec2D spos = new Vec2D(sx, sy);
    if (spos.distanceTo(mpos) < 20) {
      selection = tp;
      break;
    }
  }
}

