extends Node2D

# mainly used for documentation

#region RENDERING SETUP
# We set up a Sprite2D with a default texture.

# Make sure the texture is the same size as the window resolution.
# This means we need to scale the default size of the icon.svg from 128x128 to our window resolution.
# This can be calculated via max(1920 / 128, 1080 / 128) which sould be 15. So we scale the icon by 15.
# Being over is wasted space, but under will mean the texture is reading out of bounds.
# At minimum, we need to make sure the image is square and fits the dimensions of our window.

# Then, we position the Sprite2D to the center of the window resolution. For 1920x1080, this is 960x540.
# We can lock the RendererTexture so it doesn't accidentally move (2D View > Lock icon on toolbar; Ctrl + L);

# Create a new Shader Material, set it to the display shader of your choice. Here, we have a dot matrix.
# Set Shader params:
# Grid Size = 1024
# Dead and Alive Textures = images that are small and square.
# For initializing the render data, set a 1024x1024 noise texture

# Create a WorldEnvironment, set its mode to canvas and play with glow.

#endregion

#region COMPUTE SHADER
# Compute shader is created and edited outside Godot, still as of 4.4. It is GLSL version 450.
# Be sure to include the `#compute` directive at the top for Godot.
#endregion


func _input(event: InputEvent) -> void:
	if event.is_action_pressed('reset'):
		get_tree().reload_current_scene()
