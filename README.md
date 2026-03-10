Once inside the docker follow here : https://nvidia-isaac-ros.github.io/repositories_and_packages/isaac_ros_pose_estimation/isaac_ros_foundationpose/index.html#quickstart

To quickstart fondationpose : 
1 Terminal : 
ros2 launch isaac_ros_examples isaac_ros_examples.launch.py launch_fragments:=foundationpose interface_specs_file:=${ISAAC_ROS_WS}/isaac_ros_assets/isaac_ros_foundationpose/quickstart_interface_specs.json mesh_file_path:=${ISAAC_ROS_WS}/isaac_ros_assets/isaac_ros_foundationpose/Mustard/textured_simple.obj score_engine_file_path:=${ISAAC_ROS_WS}/isaac_ros_assets/models/foundationpose/score_trt_engine.plan refine_engine_file_path:=${ISAAC_ROS_WS}/isaac_ros_assets/models/foundationpose/refine_trt_engine.plan rt_detr_engine_file_path:=${ISAAC_ROS_WS}/isaac_ros_assets/models/synthetica_detr/sdetr_grasp.plan

from a bag : 
2 Terminal : 
ros2 bag play -l  ${ISAAC_ROS_WS}/isaac_ros_assets/isaac_ros_foundationpose/quickstart.bag/

from realsense : 
2 Terminal : 
ros2 launch isaac_ros_examples isaac_ros_examples.launch.py launch_fragments:=realsense_mono_rect_depth,foundationpose mesh_file_path:=${ISAAC_ROS_WS}/isaac_ros_assets/isaac_ros_foundationpose/Mac_and_cheese_0_1/Mac_and_cheese_0_1.obj score_engine_file_path:=${ISAAC_ROS_WS}/isaac_ros_assets/models/foundationpose/score_trt_engine.plan refine_engine_file_path:=${ISAAC_ROS_WS}/isaac_ros_assets/models/foundationpose/refine_trt_engine.plan rt_detr_engine_file_path:=${ISAAC_ROS_WS}/isaac_ros_assets/models/synthetica_detr/sdetr_grasp.plan

To launch rviz through ssh for foundationpose quickstart (after having launched the nodes in vs code docker)

ssh -X login@machine
docker exec -it -e DISPLAY=$DISPLAY foundationpose_devcontainer-foundationpose-1 \
  bash -c "xauth add $(xauth list $DISPLAY | tail -1) && bash"

from a bag :
rviz2 -d $(ros2 pkg prefix isaac_ros_foundationpose --share)/rviz/foundationpose.rviz

from rs: 
rviz2 -d  $(ros2 pkg prefix isaac_ros_foundationpose --share)/rviz/foundationpose_realsense.rviz