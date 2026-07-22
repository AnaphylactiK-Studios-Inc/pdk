# Peanut & Dreadnought Killer

The new Peanut and Dreadnought Killer game! This is built with Godot 4.7.

This README guide is written to help explain the repository, how to get set up, and how to contribute/make changes.

## Set Up

### 1. Install Godot

Download **Godot 4.7** from the official website: https://godotengine.org/download

### 2. Copy the Repository

The project lives here: https://github.com/AnaphylactiK-Studios-Inc/pdk

To get a local copy for your computer, *clone* the repository. The easiest way is probably through **GitHub Desktop**.

1. Install GitHub Desktop and sign in with your GitHub account.
2. Choose **Clone a repository**, find **pdk**, and pick a folder on your computer to save it in.
3. That folder now has the whole project!

### 3. Open the Project in Godot

1. Open Godot.
2. Choose **Import**, then find the folder you just cloned.
3. Select the **project.godot** file inside it.
4. The project opens and you are ready to go.

## Repository Organization

Here is the general structure for the project:

```
pdk/
├── project.godot          # Main Godot project file - open this to launch the project
├── icon.svg               # Application icon
├── assets/                # Art, audio, and other imported media
│   └── ...
├── scenes/                # Godot scenes (.tscn)
│   └── ...
├── scripts/               # GDScript code (.gd)
│   └── interface/         # Scripts that drive UI scenes
│       └── ...
├── .editorconfig          # Shared editor formatting settings
├── .gitattributes         # Git settings for handling Godot files
├── .gitignore             # Files Git should not track (see below)
```

### What Goes Where

- **`scenes/`** holds Godot scenes (`.tscn` files). A scene is a reusable piece of the game — a menu, a level, a character. When you build something new in the Godot editor, save the scene here.
- **`scripts/`** holds the GDScript (`.gd`) code that gives scenes their behavior. Keep scripts grouped into subfolders by purpose.
- **`assets/`** holds imported media such as images, sound, and fonts. Group these into subfolders by type or area.

You will notice files like `main_menu.gd.uid` and `anaphylactik_logo.png.import` next to the real files. Godot generates these automatically to keep track of resources. **Leave them alone and let them get committed alongside their files**.

## Working on the Project

To avoid overriding of files and changes from previous work, we should all follow this 'golden rule':

**Do not make changes directly on the main branch. Work on a branch, then open a pull request.**

Below is a brief overview of how this system should work more in-depth.

### Branches

Branches are independent workspaces where you can isolate any changes you want to make on the project without affecting the main project.

The **development** branch is where all changes you make on your branches get merged to.

The **production** branch is the official, working version of the game for whenever it is in a stable, presentable state.

In GitHub Desktop you create a branch with **Current Branch** at the top, then **New Branch**. Try to name your branch something unique but easily identifiable.

### Making Changes to your Branch

As you work, you save your progress in steps called **commits**. Each commit is a snapshot with a short note describing what you changed.

When you are ready to share, you **push** your branch to GitHub. Pushing uploads your branch so the rest of the team can see it.

### Pull Requests

A **pull request** (PR) is how you ask for your work to be added into the main branch.

1. After you push your branch, open the project on GitHub.
2. You will see a prompt to **Compare & pull request**. Click it.
3. Write a short description of what you did and why.
4. Link it to the related issue you've worked on, if applicable.
4. Create the pull request.

Teammates can then review it, leave comments, and approve it. Once it is approved, the changes get **merged** into the main branch. Please avoid merging your own pull request right away without giving others a chance to look!

### Workflow Summary

1. Make a branch.
2. Make all desired changes.
3. Push your branch to GitHub.
4. Open a pull request.
5. A teammate reviews and approves.
6. The work is merged into main.

## Some Tips

- **Pull before you start.** Before beginning new work, get the latest version so you are building on top of everyone else's recent changes. In GitHub Desktop this is the **Pull** button.
- **Keep commits small and clearly described.** It makes the history of the project easier for everyone to follow. Also makes it easy for us to revert changes if they are ever needed.

If you are ever having any issues, please ask any one of the developers for help!