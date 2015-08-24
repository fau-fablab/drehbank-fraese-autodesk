/**
  Copyright (C) 2012-2015 by Autodesk, Inc.
  All rights reserved.

  LinuxCNC Lathe  post processor configuration.

  $Revision: 38746 $
  $Date: 2015-03-26 17:18:24 +0100 (to, 26 mar 2015) $
*/

description = "LinuxCNC Turning";
vendor = "Autodesk, Inc. en Jan Houwers";
vendorUrl = "http://www.autodesk.com";
legal = "Copyright (C) 2012-2015 by Autodesk, Inc. en Jan Houwers";
certificationLevel = 2;
minimumRevision = 24000;

extension = "ngc";
programNameIsInteger = false;
setCodePage("ascii");

capabilities = CAPABILITY_TURNING;
tolerance = spatial(0.002, MM);

minimumChordLength = spatial(0.01, MM);
minimumCircularRadius = spatial(0.01, MM);
maximumCircularRadius = spatial(1000, MM);
minimumCircularSweep = toRad(0.01);
maximumCircularSweep = toRad(180);
allowHelicalMoves = true;
allowedCircularPlanes = undefined; // allow any circular motion
allowSpiralMoves = true;
highFeedrate = (unit == IN) ? 100 : 4600; // was 5000 // fablabchange



// user-defined properties
properties = {
  writeMachine: false, // write machine
  preloadTool: false, // preloads next tool on tool change if any
  showSequenceNumbers: true, // show sequence numbers
  sequenceNumberStart: 10, // first sequence number
  sequenceNumberIncrement: 2, // increment for sequence numbers
  optionalStop: true, // optional stop
  separateWordsWithSpace: true, // specifies that the words should be separated with a white space
  useRadius: false, // specifies that arcs should be output using the radius (R word) instead of the I, J, and K words.
  maximumSpindleSpeed: 4800, // specifies the maximum spindle speed // fablabchange
  useParametricFeed: false, // specifies that feed should be output using Q values
  showNotes: false, // specifies that operation notes should be output.
  useCycles: false, // specifies that drilling cycles should be used.
  useTooloffset: true // specifies that tooloffset (G43) should be used
};



var permittedCommentChars = " ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,=_-";

var gFormat = createFormat({prefix:"G", decimals:0});
var mFormat = createFormat({prefix:"M", decimals:0});
var dFormat = createFormat({prefix:"D", decimals:1});


var spatialFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceDecimal:true});
var xFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceDecimal:true, scale:2}); // diameter mode
var yFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceDecimal:true});
var zFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceDecimal:true});
var rFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceDecimal:true}); // radius
var feedFormat = createFormat({decimals:(unit == MM ? 4 : 5), forceDecimal:true});
var pitchFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceDecimal:true});
var toolFormat = createFormat({decimals:0});
var rpmFormat = createFormat({decimals:0});
var secFormat = createFormat({decimals:3, forceDecimal:true}); // seconds - range 0.001-99999.999
var milliFormat = createFormat({decimals:0}); // milliseconds // range 1-9999
var taperFormat = createFormat({decimals:1, scale:DEG});
var motionblendingFormat = createFormat({decimals:3, forceDecimal:true});
var axisoffsetFormat = createFormat({decimals:1, forceDecimal:true});

var dOutput = createVariable({}, dFormat);
var xOutput = createVariable({prefix:"X"}, xFormat);
var yOutput = createVariable({prefix:"Y"}, yFormat);
var zOutput = createVariable({prefix:"Z"}, zFormat);
var feedOutput = createVariable({prefix:"F"}, feedFormat);
var pitchOutput = createVariable({prefix:"K", force:true}, pitchFormat);
var sOutput = createVariable({prefix:"S", force:true}, rpmFormat);
var pOutput = createVariable({prefix:"P", force:true}, rpmFormat);
var motionblendingOutput = createVariable ({prefix:"P"}, motionblendingFormat);
var axisoffsetOutput = createVariable({prefix:"G"}, axisoffsetFormat);

// circular output
var iOutput = createReferenceVariable({prefix:"I", force:true}, spatialFormat);
var jOutput = createReferenceVariable({prefix:"J", force:true}, spatialFormat);
var kOutput = createReferenceVariable({prefix:"K", force:true}, spatialFormat);

var g92IOutput = createVariable({prefix:"I"}, zFormat); // no scaling

var gMotionModal = createModal({}, gFormat); // modal group 1 // G0-G3, ...
var gPlaneModal = createModal({onchange:function () {gMotionModal.reset();}}, gFormat); // modal group 2 // G17-19
var gAbsIncModal = createModal({}, gFormat); // modal group 3 // G90-91
var gFeedModeModal = createModal({}, gFormat); // modal group 5 // G98-99
var gSpindleModeModal = createModal({}, gFormat); // modal group 5 // G96-97
var gUnitModal = createModal({}, gFormat); // modal group 6 // G20-21
var gCycleModal = createModal({}, gFormat); // modal group 9 // G81, ...

// fixed settings
var firstFeedParameter = 100;
var gotSecondarySpindle = true;
var gotDoorControl = true;
var gotTailStock = true;
var gotBarFeeder = true;
var gotPartCatcher = false;

var WARNING_WORK_OFFSET = 0;

// collected state
var sequenceNumber;
var currentWorkOffset;
var optionalSection = false;
var forceSpindleSpeed = false;
var activeMovements; // do not use by default
var currentFeedId;
var maximumCircularRadiiDifference = toPreciseUnit(0.005, MM);



/**
  Writes the specified block.
*/
function writeBlock() {
  if (properties.showSequenceNumbers) {
    if (optionalSection) {
      var text = formatWords(arguments);
      if (text) {
        writeWords("/", "N" + sequenceNumber, text);
      }
    } else {
      writeWords2("N" + sequenceNumber, arguments);
    }
    sequenceNumber += properties.sequenceNumberIncrement;
  } else {
    if (optionalSection) {
      writeWords2("/", arguments);
    } else {
      writeWords(arguments);
    }
  }
}

/**
  Writes the specified optional block.
*/
function writeOptionalBlock() {
  if (properties.showSequenceNumbers) {
    var words = formatWords(arguments);
    if (words) {
      writeWords("/", "N" + sequenceNumber, words);
      sequenceNumber += properties.sequenceNumberIncrement;
    }
  } else {
    writeWords2("/", arguments);
  }
}

function formatComment(text) {
  return "(" + String(text).replace(/[\(\)]/g, "") + ")";
}

/**
  Output a comment.
*/
function writeComment(text) {
  writeln(formatComment(text));
}

function onOpen() {

  yOutput.disable();

  if (highFeedrate <= 0) {
    error(localize("You must set 'highFeedrate' because axes are not synchronized for rapid traversal."));
    return;
  }
  
  if (!properties.separateWordsWithSpace) {
    setWordSeparator("");
  }

  sequenceNumber = properties.sequenceNumberStart;
  writeln("%");

 /**
  if (programName) {
    var programId;
    try {
      programId = getAsInt(programName);
    } catch(e) {
      error(localize("Program name must be a number."));
      return;
    }
    if (!((programId >= 1) && (programId <= 9999))) {
      error(localize("Program number is out of range."));
      return;
    }
    var oFormat = createFormat({width:4, zeropad:true, decimals:0});
    if (programComment) {
      writeln("O" + oFormat.format(programId) + " (" + filterText(String(programComment).toUpperCase(), permittedCommentChars) + ")");
    } else {
      writeln("O" + oFormat.format(programId));
    }
  } else {
    error(localize("Program name has not been specified."));
    return;
  }
**/

 if (programName) {
    writeComment(programName);
  }
 if (programComment) {
    writeComment(programComment);
  }

  // dump machine configuration
  var vendor = machineConfiguration.getVendor();
  var model = machineConfiguration.getModel();
  var description = machineConfiguration.getDescription();

  if (properties.writeMachine && (vendor || model || description)) {
    writeComment(localize("Machine"));
    if (vendor) {
      writeComment("  " + localize("vendor") + ": " + vendor);
    }
    if (model) {
      writeComment("  " + localize("model") + ": " + model);
    }
    if (description) {
      writeComment("  " + localize("description") + ": "  + description);
    }
  }

  
  // absolute coordinates, feed per rev, XZ plane and incremental arc center mode and diameter mode
  writeBlock(gAbsIncModal.format(90), gFeedModeModal.format(95), gPlaneModal.format(18), axisoffsetOutput.format(92.1), gFormat.format(7), gFormat.format(80),gFormat.format(49), gFormat.format(40));
	writeBlock(gFormat.format(64), motionblendingOutput.format(tolerance)); 
  switch (unit) {
  case IN:
    writeBlock(gUnitModal.format(20));
    break;
  case MM:
    writeBlock(gUnitModal.format(21));
    break;
  }



  var usesPrimarySpindle = false;
  var usesSecondarySpindle = false;
  for (var i = 0; i < getNumberOfSections(); ++i) {
    var section = getSection(i);
    if (section.getType() != TYPE_TURNING) {
      continue;
    }
    switch (section.spindle) {
    case SPINDLE_PRIMARY:
      usesPrimarySpindle = true;
      break;
    case SPINDLE_SECONDARY:
      usesSecondarySpindle = true;
      break;
    }
  }
/**  
  
  if (usesPrimarySpindle) {
    writeBlock(gFormat.format(50), sOutput.format(properties.maximumSpindleSpeed));
    sOutput.reset();
  }
  if (gotSecondarySpindle) {
    if (usesSecondarySpindle) {
      writeBlock(gFormat.format(50), pOutput.format(properties.maximumSpindleSpeed));
      pOutput.reset();
    }
  }
**/

  // onCommand(COMMAND_START_CHIP_TRANSPORT);
}

function onComment(message) {
  writeComment(message);
}

/** Force output of X, Y, and Z. */
function forceXYZ() {
  xOutput.reset();
  yOutput.reset();
  zOutput.reset();
}

function forceFeed() {
  currentFeedId = undefined;
  feedOutput.reset();
}

/** Force output of X, Y, Z, and F on next output. */
function forceAny() {
  forceXYZ();
  forceFeed();
}

function FeedContext(id, description, feed) {
  this.id = id;
  this.description = description;
  this.feed = feed;
}

function getFeed(f) {
  if (activeMovements) {
    var feedContext = activeMovements[movement];
    if (feedContext != undefined) {
      if (!feedFormat.areDifferent(feedContext.feed, f)) {
        if (feedContext.id == currentFeedId) {
          return ""; // nothing has changed
        }
        forceFeed();
        currentFeedId = feedContext.id;
        return "F#" + (firstFeedParameter + feedContext.id);
      }
    }
    currentFeedId = undefined; // force Q feed next time
  }
  return feedOutput.format(f); // use feed value
}

function initializeActiveFeeds() {
  activeMovements = new Array();
  var movements = currentSection.getMovements();

  var id = 0;
  var activeFeeds = new Array();
  if (hasParameter("operation:tool_feedCutting")) {
    if (movements & ((1 << MOVEMENT_CUTTING) | (1 << MOVEMENT_LINK_TRANSITION) | (1 << MOVEMENT_EXTENDED))) {
      var feedContext = new FeedContext(id, localize("Cutting"), getParameter("operation:tool_feedCutting"));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_CUTTING] = feedContext;
      activeMovements[MOVEMENT_LINK_TRANSITION] = feedContext;
      activeMovements[MOVEMENT_EXTENDED] = feedContext;
    }
    ++id;
    if (movements & (1 << MOVEMENT_PREDRILL)) {
      feedContext = new FeedContext(id, localize("Predrilling"), getParameter("operation:tool_feedCutting"));
      activeMovements[MOVEMENT_PREDRILL] = feedContext;
      activeFeeds.push(feedContext);
    }
    ++id;
  }
  
  if (hasParameter("operation:finishFeedrate")) {
    if (movements & (1 << MOVEMENT_FINISH_CUTTING)) {
      var feedContext = new FeedContext(id, localize("Finish"), getParameter("operation:finishFeedrate"));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_FINISH_CUTTING] = feedContext;
    }
    ++id;
  } else if (hasParameter("operation:tool_feedCutting")) {
    if (movements & (1 << MOVEMENT_FINISH_CUTTING)) {
      var feedContext = new FeedContext(id, localize("Finish"), getParameter("operation:tool_feedCutting"));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_FINISH_CUTTING] = feedContext;
    }
    ++id;
  }
  
  if (hasParameter("operation:tool_feedEntry")) {
    if (movements & (1 << MOVEMENT_LEAD_IN)) {
      var feedContext = new FeedContext(id, localize("Entry"), getParameter("operation:tool_feedEntry"));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_LEAD_IN] = feedContext;
    }
    ++id;
  }

  if (hasParameter("operation:tool_feedExit")) {
    if (movements & (1 << MOVEMENT_LEAD_OUT)) {
      var feedContext = new FeedContext(id, localize("Exit"), getParameter("operation:tool_feedExit"));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_LEAD_OUT] = feedContext;
    }
    ++id;
  }

  if (hasParameter("operation:noEngagementFeedrate")) {
    if (movements & (1 << MOVEMENT_LINK_DIRECT)) {
      var feedContext = new FeedContext(id, localize("Direct"), getParameter("operation:noEngagementFeedrate"));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_LINK_DIRECT] = feedContext;
    }
    ++id;
  } else if (hasParameter("operation:tool_feedCutting") &&
             hasParameter("operation:tool_feedEntry") &&
             hasParameter("operation:tool_feedExit")) {
    if (movements & (1 << MOVEMENT_LINK_DIRECT)) {
      var feedContext = new FeedContext(id, localize("Direct"), Math.max(getParameter("operation:tool_feedCutting"), getParameter("operation:tool_feedEntry"), getParameter("operation:tool_feedExit")));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_LINK_DIRECT] = feedContext;
    }
    ++id;
  }
  
  if (hasParameter("operation:reducedFeedrate")) {
    if (movements & (1 << MOVEMENT_REDUCED)) {
      var feedContext = new FeedContext(id, localize("Reduced"), getParameter("operation:reducedFeedrate"));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_REDUCED] = feedContext;
    }
    ++id;
  }

  if (hasParameter("operation:tool_feedRamp")) {
    if (movements & ((1 << MOVEMENT_RAMP) | (1 << MOVEMENT_RAMP_HELIX) | (1 << MOVEMENT_RAMP_PROFILE) | (1 << MOVEMENT_RAMP_ZIG_ZAG))) {
      var feedContext = new FeedContext(id, localize("Ramping"), getParameter("operation:tool_feedRamp"));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_RAMP] = feedContext;
      activeMovements[MOVEMENT_RAMP_HELIX] = feedContext;
      activeMovements[MOVEMENT_RAMP_PROFILE] = feedContext;
      activeMovements[MOVEMENT_RAMP_ZIG_ZAG] = feedContext;
    }
    ++id;
  }
  if (hasParameter("operation:tool_feedPlunge")) {
    if (movements & (1 << MOVEMENT_PLUNGE)) {
      var feedContext = new FeedContext(id, localize("Plunge"), getParameter("operation:tool_feedPlunge"));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_PLUNGE] = feedContext;
    }
    ++id;
  }
  if (true) { // high feed
    if (movements & (1 << MOVEMENT_HIGH_FEED)) {
      var feedContext = new FeedContext(id, localize("High Feed"), this.highFeedrate);
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_HIGH_FEED] = feedContext;
    }
    ++id;
  }
  
  for (var i = 0; i < activeFeeds.length; ++i) {
    var feedContext = activeFeeds[i];
    writeBlock("#" + (firstFeedParameter + feedContext.id) + "=" + feedFormat.format(feedContext.feed), formatComment(feedContext.description));
  }
}

function getSpindle() {
  if (getNumberOfSections() == 0) {
    return SPINDLE_PRIMARY;
  }
  if (getCurrentSectionId() < 0) {
    return getSection(getNumberOfSections() - 1).spindle == 0;
  }
  if (currentSection.getType() == TYPE_TURNING) {
    return currentSection.spindle;
  } else {
    if (isSameDirection(currentSection.workPlane.forward, new Vector(0, 0, 1))) {
      return SPINDLE_PRIMARY;
    } else if (isSameDirection(currentSection.workPlane.forward, new Vector(0, 0, -1))) {
      if (!gotSecondarySpindle) {
        error(localize("Secondary spindle is not available."));
      }
      return SPINDLE_SECONDARY;
    } else {
      return SPINDLE_PRIMARY;
    }
  }
}

function onSection() {
  if (currentSection.getType() != TYPE_TURNING) {
    if (!hasParameter("operation-strategy") || (getParameter("operation-strategy") != "drill")) {
      if (currentSection.getType() == TYPE_MILLING) {
        error(localize("Milling toolpath is not supported."));
      } else {
        error(localize("Non-turning toolpath is not supported."));
      }
      return;
    }
  }

  var forceToolAndRetract = optionalSection && !currentSection.isOptional();
  optionalSection = currentSection.isOptional();  

  var turning = (currentSection.getType() == TYPE_TURNING);
  
  var insertToolCall = forceToolAndRetract || isFirstSection() ||
    currentSection.getForceToolChange && currentSection.getForceToolChange() ||
    (tool.number != getPreviousSection().getTool().number);
  
  var retracted = false; // specifies that the tool has been retracted to the safe plane
  var newSpindle = isFirstSection() ||
    (getPreviousSection().spindle != currentSection.spindle);
  var newWorkOffset = isFirstSection() ||
    (getPreviousSection().workOffset != currentSection.workOffset); // work offset changes
  var newWorkPlane = isFirstSection() ||
    !isSameDirection(getPreviousSection().getGlobalFinalToolAxis(), currentSection.getGlobalInitialToolAxis());
  if (insertToolCall || newSpindle || newWorkOffset || newWorkPlane) {
    
    // retract to safe plane
    retracted = true;
    //writeBlock(gFormat.format(53), gMotionModal.format(0), "Z" + zFormat.format(0)); // retract
    zOutput.reset();
    //writeBlock(gFormat.format(53), gMotionModal.format(0), "X" + xFormat.format(0)); // retract
    xOutput.reset();
  }

  writeln("");

  if (hasParameter("operation-comment")) {
    var comment = getParameter("operation-comment");
    if (comment) {
      writeComment(comment);
    }
  }
  
  if (properties.showNotes && hasParameter("notes")) {
    var notes = getParameter("notes");
    if (notes) {
      var lines = String(notes).split("\n");
      var r1 = new RegExp("^[\\s]+", "g");
      var r2 = new RegExp("[\\s]+$", "g");
      for (line in lines) {
        var comment = lines[line].replace(r1, "").replace(r2, "");
        if (comment) {
          writeComment(comment);
        }
      }
    }
  }
  
  if (insertToolCall) {
    retracted = true;
    onCommand(COMMAND_COOLANT_OFF);
  
    if (!isFirstSection() && properties.optionalStop) {
      onCommand(COMMAND_OPTIONAL_STOP);
    }

    if (tool.number > 99) {
      warning(localize("Tool number exceeds maximum value."));
    }

    var compensationOffset = tool.isTurningTool() ? tool.compensationOffset : tool.lengthOffset;
    if (compensationOffset > 99) {
      error(localize("Compensation offset is out of range."));
      return;
    }
    
    if (properties.useTooloffset){
    		writeBlock("T" + toolFormat.format(tool.number), mFormat.format(6), gFormat.format(43));
     }
    else {
     writeBlock("T" + toolFormat.format(tool.number), mFormat.format(6));
  	 }

    
    if (tool.comment) {
      writeComment(tool.comment);
    }

    if (properties.preloadTool) {
      var nextTool = getNextTool(tool.number);
      if (nextTool) {
        var compensationOffset = nextTool.isTurningTool() ? nextTool.compensationOffset : nextTool.lengthOffset;
        if (compensationOffset > 99) {
          error(localize("Compensation offset is out of range."));
          return;
        }
        writeBlock("T" + toolFormat.format(nextTool.number * 100 + compensationOffset));
      } else {
        // preload first tool
        var section = getSection(0);
        var firstTool = section.getTool().number;
        if (tool.number != firstTool.number) {
          var compensationOffset = firstTool.isTurningTool() ? firstTool.compensationOffset : firstTool.lengthOffset;
          if (compensationOffset > 99) {
            error(localize("Compensation offset is out of range."));
            return;
          }
          writeBlock("T" + toolFormat.format(firstTool.number * 100 + compensationOffset));
        }
      }
    }
  }

  if (newSpindle) {
    // select spindle if required
  }
  // see page 138 in 96-8700an for stock transfer / G199/G198

  if (insertToolCall ||
      newSpindle ||
      isFirstSection() ||
      (rpmFormat.areDifferent(tool.spindleRPM, sOutput.getCurrent())) ||
      (tool.clockwise != getPreviousSection().getTool().clockwise)) {
    if (tool.spindleRPM < 50) { // fablabchange. was: 1
      error(localize("Spindle speed out of range."));
      return;
    }
    if (turning) {
      if (tool.spindleRPM > maximumSpindleSpeed) { // fablabchange
        warning(localize("Spindle speed exceeds maximum value."));
      }
    } 
	
/* fablabchange: changed this into a comment
	else {
      if (tool.spindleRPM > 3000) {
        warning(localize("Spindle speed exceeds maximum value."));
      }
    }
*/

    switch (currentSection.spindle) {
    case SPINDLE_PRIMARY: // main spindle
      if (true) {
        gFeedModeModal.reset();
        if (currentSection.feedMode == FEED_PER_REVOLUTION) {
          writeBlock(gFeedModeModal.format(95));
        } else {
          writeBlock(gFeedModeModal.format(94));
        }

        //if (gotTailStock) {
        //  writeBlock(mFormat.format(currentSection.tailstock ? 21 : 22));
        // }
        // writeBlock(mFormat.format(clampPrimaryChuck ? 10 : 11));
        // writeBlock(mFormat.format(clampSecondaryChuck ? 110 : 111));
  
	//begin toni todo
        gSpindleModeModal.reset();
        if (currentSection.getTool().getSpindleMode() == SPINDLE_CONSTANT_SURFACE_SPEED) {
        var maximumSpindleSpeed = (getParameter("operation:tool_maximumSpindleSpeed") > 0) ? Math.min(getParameter("operation:tool_maximumSpindleSpeed"), properties.maximumSpindleSpeed) : properties.maximumSpindleSpeed;  
        writeBlock(gSpindleModeModal.format(96), dOutput.format(maximumSpindleSpeed), sOutput.format(tool.surfaceSpeed /1000 * ((unit == MM) ? 1 : 1/12.0)), mFormat.format(tool.clockwise ? 3 : 4));
  
        //todo  writeBlock(gFormat.format(50), sOutput.format(maximumSpindleSpeed));
        sOutput.reset();
        } else {
        writeBlock(gSpindleModeModal.format(97), sOutput.format(tool.spindleRPM), mFormat.format(tool.clockwise ? 3 : 4));
        }
        //end toni
  
//       gSpindleModeModal.reset();
//       if (currentSection.getTool().getSpindleMode() == SPINDLE_CONSTANT_SURFACE_SPEED) {
//		  // When Setting 9 is set to INCH, the S value specifies Surface Feet Per Minute. When Setting 9 is set to MM, the S value specifies Surface Meters Per Minute.
//
//		// we have to create a string in form of "Dmaximumspindlevalue" as linuxcnc cant take care of its max. temp itself. it should write D4600 for Fablabs turning machine. // fablabchange
//			var firstpart = "D";
//			var completestring = firstpart.concat(properties.maximumSpindleSpeed);
//		// were done creating this string.
//
//          writeBlock(gSpindleModeModal.format(96), completestring, sOutput.format(tool.surfaceSpeed * ((unit == MM) ? 1/1000.0 : 1/12.0)), mFormat.format(tool.clockwise ? 3 : 4)); // was: tool.clockwise ? 4 : 3 // fablabchange: (switch 3 and 4, add "D", maximumSpindleSpeed)
//          var maximumSpindleSpeed = (tool.maximumSpindleSpeed > 0) ? Math.min(tool.maximumSpindleSpeed, properties.maximumSpindleSpeed) : properties.maximumSpindleSpeed;
//          // writeBlock(gFormat.format(50), sOutput.format(maximumSpindleSpeed));
//          sOutput.reset();
//        } else {
//          writeBlock(gSpindleModeModal.format(97), sOutput.format(tool.spindleRPM), mFormat.format(tool.clockwise ? 3 : 4));
//        }
        // wait for spindle here if required
      }
      break;
    case SPINDLE_SECONDARY: // sub spindle
      if (!gotSecondarySpindle) {
        error(localize("Secondary spindle is not available."));
        return;
      }
      if (true) {
        // use could also swap spindles using G14/G15

        gFeedModeModal.reset();
        if (currentSection.feedMode == FEED_PER_REVOLUTION) {
          writeBlock(gFeedModeModal.format(99));
        } else {
          writeBlock(gFeedModeModal.format(98));
        }

        if (gotTailStock && currentSection.tailstock) {
          error(localize("Tail stock is not supported for secondary spindle."));
          return;
          // writeBlock(mFormat.format(currentSection.tailstock ? 21 : 22));
        }
        // writeBlock(mFormat.format(clampPrimaryChuck ? 10 : 11));
        // writeBlock(mFormat.format(clampSecondaryChuck ? 110 : 111));
        


  
        gSpindleModeModal.reset();
        if (currentSection.getTool().getSpindleMode() == SPINDLE_CONSTANT_SURFACE_SPEED) {
		  // When Setting 9 is set to INCH, the S value specifies Surface Feet Per Minute. When Setting 9 is set to MM, the S value specifies Surface Meters Per Minute.
          writeBlock(gSpindleModeModal.format(96), pOutput.format(tool.surfaceSpeed * ((unit == MM) ? 1/1000.0 : 1/12.0)), mFormat.format(tool.clockwise ? 143 : 144));
          var maximumSpindleSpeed = (tool.maximumSpindleSpeed > 0) ? Math.min(tool.maximumSpindleSpeed, properties.maximumSpindleSpeed) : properties.maximumSpindleSpeed;
          // writeBlock(gFormat.format(50), pOutput.format(maximumSpindleSpeed));
          pOutput.reset();
        } else {
          writeBlock(gSpindleModeModal.format(97), pOutput.format(tool.spindleRPM), mFormat.format(tool.clockwise ? 143 : 144));
        }
        // wait for spindle here if required
      }
      break;
    }
  }

  // wcs
  var workOffset = currentSection.workOffset;
  if (workOffset == 0) {
    warningOnce(localize("Work offset has not been specified. Using G54 as WCS."), WARNING_WORK_OFFSET);
    workOffset = 1;
  }
  if (workOffset > 0) {
    if (workOffset > 6) {
      // alternatively use G154 P1-99
      var code = workOffset - 6;
      if (code >= 26) {
        error(localize("Work offset out of range."));
        return;
      }
      if (workOffset != currentWorkOffset) {
        writeBlock(gFormat.format(110 + code)); // G110->G129
        currentWorkOffset = workOffset;
      }
    } else {
      if (workOffset != currentWorkOffset) {
        writeBlock(gFormat.format(53 + workOffset)); // G54->G59
        currentWorkOffset = workOffset;
      }
    }
  }

  // set coolant after we have positioned at Z
  setCoolant(tool.coolant);

  forceAny();
  gMotionModal.reset();

  setRotation(currentSection.workPlane);

  var initialPosition = getFramePosition(currentSection.getInitialPosition());
  if (!retracted) {
    // TAG: need to retract along X or Z
    if (getCurrentPosition().z < initialPosition.z) {
      writeBlock(gMotionModal.format(0), zOutput.format(initialPosition.z));
    }
  }

  if (insertToolCall) {
    gMotionModal.reset();
    
    writeBlock(
      gMotionModal.format(0), xOutput.format(initialPosition.x), yOutput.format(initialPosition.y), zOutput.format(initialPosition.z)
    );

    gMotionModal.reset();
  }

  if (gotPartCatcher &&
      (currentSection.partCatcher ||
       (typeof currentSection.partCatcher == "undefined") &&
       hasParameter("operation-strategy") &&
       (getParameter("operation-strategy") == "turningPart"))) {
    // activate part catcher here
  }

  if (properties.useParametricFeed &&
      hasParameter("operation-strategy") &&
      (getParameter("operation-strategy") != "drill")) {
    if (!insertToolCall &&
        activeMovements &&
        (getCurrentSectionId() > 0) &&
        (getPreviousSection().getPatternId() == currentSection.getPatternId())) {
      // use the current feeds
    } else {
      initializeActiveFeeds();
    }
  } else {
    activeMovements = undefined;
  }

  if (insertToolCall || retracted) {
    gPlaneModal.reset();
  }
}

function onDwell(seconds) {
  if (seconds > 99999.999) {
    warning(localize("Dwelling time is out of range."));
  }
  milliseconds = clamp(1, seconds * 1000, 99999999);
  writeBlock(/*gFeedModeModal.format(94),*/ gFormat.format(4), "P" + milliFormat.format(milliseconds));
}

var pendingRadiusCompensation = -1;

function onRadiusCompensation() {
  pendingRadiusCompensation = radiusCompensation;
}

var resetFeed = false;

function getHighfeedrate(radius) {
  if (currentSection.feedMode == FEED_PER_REVOLUTION) {
    var rpm = tool.spindleRPM; // rev/min
    if (currentSection.getTool().getSpindleMode() == SPINDLE_CONSTANT_SURFACE_SPEED) {
      var O = 2 * Math.PI * radius; // in/rev
      rpm = tool.surfaceSpeed/O; // in/min div in/rev => rev/min
    }
    return highFeedrate/rpm; // in/min div rev/min => in/rev
  }
  return highFeedrate;
}

function onRapid(_x, _y, _z) {
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);
  if (x || y || z) {
    var useG1 = ((x ? 1 : 0) + (y ? 1 : 0) + (z ? 1 : 0)) > 1;
    if (pendingRadiusCompensation >= 0) {
      pendingRadiusCompensation = -1;
      if (useG1) {
        switch (radiusCompensation) {
        case RADIUS_COMPENSATION_LEFT:
          writeBlock(gMotionModal.format(1), gFormat.format(41), x, y, z, getFeed(getHighfeedrate(_x)));
          break;
        case RADIUS_COMPENSATION_RIGHT:
          writeBlock(gMotionModal.format(1), gFormat.format(42), x, y, z, getFeed(getHighfeedrate(_x)));
          break;
        default:
          writeBlock(gMotionModal.format(1), gFormat.format(40), x, y, z, getFeed(getHighfeedrate(_x)));
        }
      } else {
        switch (radiusCompensation) {
        case RADIUS_COMPENSATION_LEFT:
          writeBlock(gMotionModal.format(0), gFormat.format(41), x, y, z);
          break;
        case RADIUS_COMPENSATION_RIGHT:
          writeBlock(gMotionModal.format(0), gFormat.format(42), x, y, z);
          break;
        default:
          writeBlock(gMotionModal.format(0), gFormat.format(40), x, y, z);
        }
      }
    }
    if (useG1) {
      // axes are not synchronized
      writeBlock(gMotionModal.format(1), x, y, z, getFeed(getHighfeedrate(_x)));
    } else {
      writeBlock(gMotionModal.format(0), x, y, z);
      forceFeed();
    }
    resetFeed = false;
  }
}

function onLinear(_x, _y, _z, feed) {
  if (isSpeedFeedSynchronizationActive()) {
    resetFeed = true;
    var threadPitch = getParameter("operation:threadPitch");
    var threadsPerInch = 1.0/threadPitch; // per mm for metric
    writeBlock(gMotionModal.format(33), xOutput.format(_x), yOutput.format(_y), zOutput.format(_z), pitchOutput.format(1/threadsPerInch));
    return;
  }
  if (resetFeed) {
    resetFeed = false;
    forceFeed();
  }
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);
  var f = getFeed(feed);
  if (x || y || z) {
    if (pendingRadiusCompensation >= 0) {
      pendingRadiusCompensation = -1;
      writeBlock(gPlaneModal.format(18));
      switch (radiusCompensation) {
      case RADIUS_COMPENSATION_LEFT:
        writeBlock(gMotionModal.format(isSpeedFeedSynchronizationActive() ? 32 : 1), gFormat.format(41), x, y, z, f);
        break;
      case RADIUS_COMPENSATION_RIGHT:
        writeBlock(gMotionModal.format(isSpeedFeedSynchronizationActive() ? 32 : 1), gFormat.format(42), x, y, z, f);
        break;
      default:
        writeBlock(gMotionModal.format(isSpeedFeedSynchronizationActive() ? 32 : 1), gFormat.format(40), x, y, z, f);
      }
    } else {
      writeBlock(gMotionModal.format(isSpeedFeedSynchronizationActive() ? 32 : 1), x, y, z, f);
    }
  } else if (f) {
    if (getNextRecord().isMotion()) { // try not to output feed without motion
      forceFeed(); // force feed on next line
    } else {
      writeBlock(gMotionModal.format(isSpeedFeedSynchronizationActive() ? 32 : 1), f);
    }
  }
}

function onCircular(clockwise, cx, cy, cz, x, y, z, feed) {
  if (isSpeedFeedSynchronizationActive()) {
    error(localize("Speed-feed synchronization is not supported for circular moves."));
    return;
  }
  
  if (pendingRadiusCompensation >= 0) {
    error(localize("Radius compensation cannot be activated/deactivated for a circular move."));
    return;
  }

  var start = getCurrentPosition();

  if (isFullCircle()) {
    if (properties.useRadius || isHelical()) { // radius mode does not support full arcs
      linearize(tolerance);
      return;
    }
    switch (getCircularPlane()) {
    case PLANE_XY:
      writeBlock(gPlaneModal.format(17), gMotionModal.format(clockwise ? 2 : 3), iOutput.format(cx - start.x, 0), jOutput.format(cy - start.y, 0), getFeed(feed));
      break;
    case PLANE_ZX:
      writeBlock(gPlaneModal.format(18), gMotionModal.format(clockwise ? 2 : 3), iOutput.format(cx - start.x, 0), kOutput.format(cz - start.z, 0), getFeed(feed));
      break;
    case PLANE_YZ:
      writeBlock(gPlaneModal.format(19), gMotionModal.format(clockwise ? 2 : 3), jOutput.format(cy - start.y, 0), kOutput.format(cz - start.z, 0), getFeed(feed));
      break;
    default:
      linearize(tolerance);
    }
  } else if (!properties.useRadius) {
    switch (getCircularPlane()) {
    case PLANE_XY:
      writeBlock(gPlaneModal.format(17), gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zOutput.format(z), iOutput.format(cx - start.x, 0), jOutput.format(cy - start.y, 0), getFeed(feed));
      break;
    case PLANE_ZX:
      writeBlock(gPlaneModal.format(18), gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zOutput.format(z), iOutput.format(cx - start.x, 0), kOutput.format(cz - start.z, 0), getFeed(feed));
      break;
    case PLANE_YZ:
      writeBlock(gPlaneModal.format(19), gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zOutput.format(z), jOutput.format(cy - start.y, 0), kOutput.format(cz - start.z, 0), getFeed(feed));
      break;
    default:
      linearize(tolerance);
    }
  } else { // use radius mode
    var r = getCircularRadius();
    if (toDeg(getCircularSweep()) > (180 + 1e-9)) {
      r = -r; // allow up to <360 deg arcs
    }
    switch (getCircularPlane()) {
    case PLANE_XY:
      writeBlock(gPlaneModal.format(17), gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zOutput.format(z), "R" + rFormat.format(r), getFeed(feed));
      break;
    case PLANE_ZX:
      writeBlock(gPlaneModal.format(18), gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zOutput.format(z), "R" + rFormat.format(r), getFeed(feed));
      break;
    case PLANE_YZ:
      writeBlock(gPlaneModal.format(19), gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zOutput.format(z), "R" + rFormat.format(r), getFeed(feed));
      break;
    default:
      linearize(tolerance);
    }
  }
}

function onCycle() {
}

function getCommonCycle(x, y, z, r) {
  forceXYZ(); // force xyz on first drill hole of any cycle
  return [xOutput.format(x), yOutput.format(y),
    zOutput.format(z),
    "R" + spatialFormat.format(r)];
}

function onCyclePoint(x, y, z) {
  if (!properties.useCycles || currentSection.isMultiAxis()) {
    expandCyclePoint(x, y, z);
    return;
  }

  if (isSameDirection(currentSection.workPlane.forward, new Vector(0, 0, 1)) ||
      isSameDirection(currentSection.workPlane.forward, new Vector(0, 0, -1))) {
    writeBlock(gPlaneModal.format(17)); // XY plane
  } else {
    expandCyclePoint(x, y, z);
    return;
  }

  switch (cycleType) {
  case "thread-turning":
    var i = -cycle.incrementalX; // positive if taper goes down - delta radius
    var threadsPerInch = 1.0/cycle.pitch; // per mm for metric
    var f = 1/threadsPerInch;
    writeBlock(gMotionModal.format(92), xOutput.format(x - cycle.incrementalX), yOutput.format(y), zOutput.format(z), conditional(zFormat.isSignificant(i), g92IOutput.format(i)), pitchOutput.format(f));
    forceFeed();
    return;
  }

  if (isFirstCyclePoint()) {
    switch (gPlaneModal.getCurrent()) {
    case 17:
      writeBlock(gMotionModal.format(0), zOutput.format(cycle.clearance));
      break;
    case 18:
      writeBlock(gMotionModal.format(0), yOutput.format(cycle.clearance));
      break;
    case 19:
      writeBlock(gMotionModal.format(0), xOutput.format(cycle.clearance));
      break;
    default:
      error(localize("Unsupported drilling orientation."));
      return;
    }

    repositionToCycleClearance(cycle, x, y, z);
    
    // return to initial Z which is clearance plane and set absolute mode

    var F = cycle.feedrate;
    var P = (cycle.dwell == 0) ? 0 : clamp(1, cycle.dwell * 1000, 99999999); // in milliseconds

    switch (cycleType) {
    case "drilling":
      writeBlock(
        gCycleModal.format(81),
        getCommonCycle(x, y, z, cycle.retract),
        feedOutput.format(F)
      );
      break;
    case "counter-boring":
      if (P > 0) {
        writeBlock(
          gCycleModal.format(82),
          getCommonCycle(x, y, z, cycle.retract),
          "P" + milliFormat.format(P),
          feedOutput.format(F)
        );
      } else {
        writeBlock(
          gCycleModal.format(81),
          getCommonCycle(x, y, z, cycle.retract),
          feedOutput.format(F)
        );
      }
      break;
    case "chip-breaking":
      // cycle.accumulatedDepth is ignored
      if (P > 0) {
        expandCyclePoint(x, y, z);
      } else {
        writeBlock(
          gCycleModal.format(73),
          getCommonCycle(x, y, z, cycle.retract),
          "Q" + spatialFormat.format(cycle.incrementalDepth),
          feedOutput.format(F)
        );
      }
      break;
    case "deep-drilling":
      // either use Q or I,J,K
      writeBlock(
        gCycleModal.format(83),
        getCommonCycle(x, y, z, cycle.retract),
        "Q" + spatialFormat.format(cycle.incrementalDepth),
        // conditional(cycle.incrementalDepthReduction > 0, "J" + spatialFormat.format(cycle.incrementalDepthReduction)),
        // conditional(cycle.minimumIncrementalDepth > 0, "K" + spatialFormat.format(cycle.minimumIncrementalDepth)),
        conditional(P > 0, "P" + milliFormat.format(P)),
        feedOutput.format(F)
      );
      break;
    case "tapping":
      if (!F) {
        F = tool.getTappingFeedrate();
      }
      writeBlock(
        gCycleModal.format((tool.type == TOOL_TAP_LEFT_HAND) ? 74 : 84),
        getCommonCycle(x, y, z, cycle.retract),
        "P" + milliFormat.format(P),
        pitchOutput.format(F)
      );
      forceFeed();
      break;
    case "left-tapping":
      if (!F) {
        F = tool.getTappingFeedrate();
      }
      writeBlock(
        gCycleModal.format(74),
        getCommonCycle(x, y, z, cycle.retract),
        "P" + milliFormat.format(P),
        pitchOutput.format(F)
      );
      forceFeed();
      break;
    case "right-tapping":
      if (!F) {
        F = tool.getTappingFeedrate();
      }
      writeBlock(
        gCycleModal.format(84),
        getCommonCycle(x, y, z, cycle.retract),
        "P" + milliFormat.format(P),
        pitchOutput.format(F)
      );
      forceFeed();
      break;
    case "tapping-with-chip-breaking":
    case "left-tapping-with-chip-breaking":
    case "right-tapping-with-chip-breaking":
      if (!F) {
        F = tool.getTappingFeedrate();
      }
      writeBlock(
        gCycleModal.format((tool.type == TOOL_TAP_LEFT_HAND ? 74 : 84)),
        getCommonCycle(x, y, z, cycle.retract),
        "P" + milliFormat.format(P),
        "Q" + spatialFormat.format(cycle.incrementalDepth),
        pitchOutput.format(F)
      );
      forceFeed();
      break;
    case "fine-boring":
      writeBlock(
        gCycleModal.format(76),
        getCommonCycle(x, y, z, cycle.retract),
        "P" + milliFormat.format(P), // not optional
        "Q" + spatialFormat.format(cycle.shift),
        feedOutput.format(F)
      );
      break;
    case "reaming":
      if (P > 0) {
        writeBlock(
          gCycleModal.format(89),
          getCommonCycle(x, y, z, cycle.retract),
          "P" + milliFormat.format(P),
          feedOutput.format(F)
        );
      } else {
        writeBlock(
          gCycleModal.format(85),
          getCommonCycle(x, y, z, cycle.retract),
          feedOutput.format(F)
        );
      }
      break;
    case "stop-boring":
      if (P > 0) {
        expandCyclePoint(x, y, z);
      } else {
        writeBlock(
          gCycleModal.format(86),
          getCommonCycle(x, y, z, cycle.retract),
          feedOutput.format(F)
        );
      }
      break;
    case "boring":
      if (P > 0) {
        writeBlock(
          gCycleModal.format(89),
          getCommonCycle(x, y, z, cycle.retract),
          "P" + milliFormat.format(P), // not optional
          feedOutput.format(F)
        );
      } else {
        writeBlock(
          gCycleModal.format(85),
          getCommonCycle(x, y, z, cycle.retract),
          feedOutput.format(F)
        );
      }
      break;
    default:
      expandCyclePoint(x, y, z);
    }
  } else {
    if (cycleExpanded) {
      expandCyclePoint(x, y, z);
    } else {
      var _x = xOutput.format(x);
      var _y = yOutput.format(y);
      var _z = zOutput.format(z);
      if (!_x && !_y && !_z) {
        switch (gPlaneModal.getCurrent()) {
        case 17: // XY
          xOutput.reset(); // at least one axis is required
          _x = xOutput.format(x);
          break;
        case 18: // ZX
          zOutput.reset(); // at least one axis is required
          _z = zOutput.format(z);
          break;
        case 19: // YZ
          yOutput.reset(); // at least one axis is required
          _y = yOutput.format(y);
          break;
        }
      }
      writeBlock(_x, _y, _z);
    }
  }
}

function onCycleEnd() {
  if (!cycleExpanded) {
    switch (cycleType) {
    case "thread-turning":
      forceFeed();
      xOutput.reset();
      zOutput.reset();
      g92IOutput.reset();
      break;
    default:
      writeBlock(gCycleModal.format(80));
    }
  }
}

var currentCoolantMode = COOLANT_OFF;

function setCoolant(coolant) {
  if (coolant == currentCoolantMode) {
    return; // coolant is already active
  }

  var m = undefined;
  if (coolant == COOLANT_OFF) {
    if (currentCoolantMode == COOLANT_THROUGH_TOOL) {
      m = 89;
    } else if (currentCoolantMode == COOLANT_AIR) {
      m = 84;
    } else {
      m = 9;
    }
    writeBlock(mFormat.format(m));
    currentCoolantMode = COOLANT_OFF;
    return;
  }

  if (currentCoolantMode != COOLANT_OFF) {
    setCoolant(COOLANT_OFF);
  }

  switch (coolant) {
  case COOLANT_FLOOD:
    m = 8;
    break;
  case COOLANT_THROUGH_TOOL:
    m = 88;
    break;
  case COOLANT_AIR:
    m = 83;
    break;
  default:
    warning(localize("Coolant not supported."));
    if (currentCoolantMode == COOLANT_OFF) {
      return;
    }
    coolant = COOLANT_OFF;
    m = 9;
  }

  writeBlock(mFormat.format(m));
  currentCoolantMode = coolant;
}

function onCommand(command) {
  switch (command) {
  case COMMAND_COOLANT_OFF:
    setCoolant(COOLANT_OFF);
    break;
  case COMMAND_COOLANT_ON:
    setCoolant(COOLANT_FLOOD);
    break;
  case COMMAND_LOCK_MULTI_AXIS:
    writeBlock(mFormat.format((getSpindle() == 0) ? 14 : 114));
    break;
  case COMMAND_UNLOCK_MULTI_AXIS:
    writeBlock(mFormat.format((getSpindle() == 0) ? 15 : 115));
    break;
  case COMMAND_START_CHIP_TRANSPORT:
    writeBlock(mFormat.format(31));
    break;
  case COMMAND_STOP_CHIP_TRANSPORT:
    writeBlock(mFormat.format(33));
    break;
  case COMMAND_OPEN_DOOR:
    if (gotDoorControl) {
      writeBlock(mFormat.format(85)); // optional
    }
    break;
  case COMMAND_CLOSE_DOOR:
    if (gotDoorControl) {
      writeBlock(mFormat.format(86)); // optional
    }
    break;
  case COMMAND_BREAK_CONTROL:
    break;
  case COMMAND_TOOL_MEASURE:
    break;
  case COMMAND_ACTIVATE_SPEED_FEED_SYNCHRONIZATION:
    break;
  case COMMAND_DEACTIVATE_SPEED_FEED_SYNCHRONIZATION:
    break;

  case COMMAND_STOP:
    writeBlock(mFormat.format(0));
    forceSpindleSpeed = true;
    break;
  case COMMAND_OPTIONAL_STOP:
    writeBlock(mFormat.format(1));
    break;
  case COMMAND_END:
    writeBlock(mFormat.format(2));
    break;
  case COMMAND_SPINDLE_CLOCKWISE:
    switch (currentSection.spindle) {
    case SPINDLE_PRIMARY:
      writeBlock(mFormat.format(3)); // was: .format(3)
      break;
    case SPINDLE_SECONDARY:
      writeBlock(mFormat.format(143)); // was: format.143
      break;
    }
    break;
  case COMMAND_SPINDLE_COUNTERCLOCKWISE:
    switch (currentSection.spindle) {
    case SPINDLE_PRIMARY:
      writeBlock(mFormat.format(4)); // was: .format(4)
      break;
    case SPINDLE_SECONDARY:
      writeBlock(mFormat.format(144)); // was: format.144
      break;
    }
    break;
  case COMMAND_START_SPINDLE:
    onCommand(tool.clockwise ? COMMAND_SPINDLE_CLOCKWISE : COMMAND_SPINDLE_COUNTERCLOCKWISE);
    return;
  case COMMAND_STOP_SPINDLE:
    switch (currentSection.spindle) {
    case SPINDLE_PRIMARY:
      writeBlock(mFormat.format(5));
      break;
    case SPINDLE_SECONDARY:
      writeBlock(mFormat.format(145));
      break;
    }
    break;
  case COMMAND_ORIENTATE_SPINDLE:
    if (getSpindle() == 0) {
      writeBlock(mFormat.format(19)); // use P or R to set angle (optional)
    } else {
      writeBlock(mFormat.format(119));
    }
    break;
  //case COMMAND_CLAMP: // add support for clamping
  //case COMMAND_UNCLAMP: // add support for clamping
  default:
    onUnsupportedCommand(command);
  }
}

function onSectionEnd() {
  forceAny();

  if (gotPartCatcher &&
      (currentSection.partCatcher ||
       (typeof currentSection.partCatcher == "undefined") &&
       hasParameter("operation-strategy") &&
       (getParameter("operation-strategy") == "turningPart"))) {
    // deactivate part catcher here
  }
}

function onClose() {
  writeln("");

  optionalSection = false;

  onCommand(COMMAND_COOLANT_OFF);

  // we might want to retract in Z before X
  // Output.reset();
  // writeBlock(gFormat.format(53), gMotionModal.format(0), "Z" + zFormat.format(0)); // retract
  // zOutput.reset();


  onImpliedCommand(COMMAND_END);
  onImpliedCommand(COMMAND_STOP_SPINDLE);
  writeBlock(mFormat.format(30)); // stop program, spindle stop, coolant off
  writeln("%");
}
