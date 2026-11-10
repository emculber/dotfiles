#!/bin/sh
# Prints the audio outputs and the apps playing, one tab-separated line each,
# for the volume widget's panel (widgets/volume.lua):
#   default <node.name of the default output>
#   sink    <id> <serial> <node.name> <description>
#   stream  <id> <app> <media name> <channel volume, linear> <muted> <target.object> <linked sink ids>
pw-dump 2>/dev/null | jq -r '
. as $all
| ([ $all[] | select(.type == "PipeWire:Interface:Link") | { out: .info["output-node-id"], in: .info["input-node-id"] } ]) as $links
| ([ $all[] | select(.type == "PipeWire:Interface:Metadata" and .props["metadata.name"] == "default") | .metadata[]? ]) as $meta
| ([ $meta[] | select(.key == "default.audio.sink") | .value.name? // empty ] | .[0] // "") as $default
| "default\t\($default)",
  ($all[] | select(.type == "PipeWire:Interface:Node" and .info.props["media.class"] == "Audio/Sink")
   | .info.props as $p
   | "sink\t\(.id)\t\($p["object.serial"])\t\($p["node.name"])\t\($p["node.description"] // $p["node.nick"] // $p["node.name"])"),
  ($all[] | select(.type == "PipeWire:Interface:Node" and .info.props["media.class"] == "Stream/Output/Audio")
   | . as $n
   | .info.props as $p
   | ((.info.params.Props // []) | map(select(.channelVolumes)) | .[0] // {}) as $v
   | ([ $meta[] | select(.subject == $n.id and .key == "target.object") | .value ] | .[0] // "") as $target
   | ([ $links[] | select(.out == $n.id) | .in ] | unique | map(tostring) | join(",")) as $linked
   | [ "stream", $n.id, ($p["application.name"] // $p["application.process.binary"] // $p["node.name"] // "?"),
       ($p["media.name"] // ""), (($v.channelVolumes // [1])[0]), ($v.mute // false), $target, $linked ]
   | map(tostring | gsub("[\t\n]"; " ")) | join("\t"))
'
