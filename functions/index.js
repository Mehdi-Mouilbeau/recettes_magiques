require("./config/admin");

const { processRecipe } = require("./services/ocrService");
const { regenerateRecipeImage } = require("./services/imageService");
const {
  generateRecipeImageOnCreate,
  generateRecipeImageOnQueued,
} = require("./triggers/imageTriggers");

exports.processRecipe = processRecipe;
exports.regenerateRecipeImage = regenerateRecipeImage;
exports.shareRecipeToGroup =
  require("./triggers/shareRecipeToGroup").shareRecipeToGroup;
exports.onGroupMemberCreated =
  require("./triggers/onGroupMemberCreated").onGroupMemberCreated;
exports.generateRecipeImageOnCreate = generateRecipeImageOnCreate;
exports.generateRecipeImageOnQueued = generateRecipeImageOnQueued;
